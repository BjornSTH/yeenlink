// Package tlsmode — сертификат сервера в четырёх режимах (spec/server.md,
// «Сертификаты») и хеш сертификата каждого соединения для server_sig.
package tlsmode

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/hex"
	"encoding/pem"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"math/big"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/caddyserver/certmagic"

	"yeenlink/server/internal/config"
	"yeenlink/server/pkg/protocol"
)

// Setup — готовый TLS и способ узнать хеш сертификата соединения.
type Setup struct {
	// TLSConfig — nil в режиме proxy (сервер слушает без TLS).
	TLSConfig *tls.Config
	// HTTPChallenge — обработчик для порта HTTP-01 (только acme), иначе nil.
	HTTPChallenge http.Handler
	// Fingerprint — SHA-256 сертификата в режимах self-signed и file, для
	// печати при init и для приглашений (фаза 4).
	Fingerprint string

	proxyHashes [][]byte
	served      sync.Map // net.Conn (сырое) → []byte (хеш отданного сертификата)
}

type connKey struct{}

// Build готовит сертификат по конфигу. В режиме acme получает сертификат
// синхронно (certmagic), поэтому вызывайте с разумным таймаутом.
func Build(ctx context.Context, c config.Config, log *slog.Logger) (*Setup, error) {
	s := &Setup{}
	switch c.TLS.Mode {
	case config.TLSProxy:
		for _, p := range c.TLS.ProxyCerts {
			der, err := leafDER(p)
			if err != nil {
				return nil, fmt.Errorf("tls.proxy_cert %s: %w", p, err)
			}
			s.proxyHashes = append(s.proxyHashes, protocol.CertHash(der))
		}
		if len(s.proxyHashes) == 0 {
			log.Warn("tls.mode = proxy без tls.proxy_cert: клиенты предупредят, что подмена сертификата не исключена")
		}
		return s, nil
	case config.TLSFile:
		cert, err := tls.LoadX509KeyPair(c.TLS.CertFile, c.TLS.KeyFile)
		if err != nil {
			return nil, err
		}
		s.Fingerprint = Fingerprint(cert.Certificate[0])
		s.TLSConfig = s.wrap(&tls.Config{Certificates: []tls.Certificate{cert}})
		return s, nil
	case config.TLSSelfSigned:
		cert, err := selfSigned(c.CertDir(), c.Host)
		if err != nil {
			return nil, err
		}
		s.Fingerprint = Fingerprint(cert.Certificate[0])
		s.TLSConfig = s.wrap(&tls.Config{Certificates: []tls.Certificate{cert}})
		return s, nil
	case config.TLSACME:
		return s, s.acme(ctx, c, log)
	}
	return nil, fmt.Errorf("tlsmode: неизвестный режим %q", c.TLS.Mode)
}

// wrap запоминает хеш отданного сертификата за сырым соединением.
func (s *Setup) wrap(base *tls.Config) *tls.Config {
	cfg := base.Clone()
	inner := base.GetCertificate
	certs := base.Certificates
	cfg.Certificates = nil
	cfg.MinVersion = tls.VersionTLS12
	cfg.GetCertificate = func(hello *tls.ClientHelloInfo) (*tls.Certificate, error) {
		var cert *tls.Certificate
		if inner != nil {
			var err error
			if cert, err = inner(hello); err != nil {
				return nil, err
			}
		} else {
			cert = &certs[0]
		}
		if cert != nil && len(cert.Certificate) > 0 && hello.Conn != nil {
			s.served.Store(hello.Conn, protocol.CertHash(cert.Certificate[0]))
		}
		return cert, nil
	}
	if len(cfg.NextProtos) == 0 {
		cfg.NextProtos = []string{"http/1.1"}
	}
	return cfg
}

// ConnContext — для http.Server.ConnContext: запоминает сырое соединение.
func (s *Setup) ConnContext(ctx context.Context, c net.Conn) context.Context {
	if tc, ok := c.(*tls.Conn); ok {
		c = tc.NetConn()
	}
	return context.WithValue(ctx, connKey{}, c)
}

// ConnState — для http.Server.ConnState: забывает закрытые соединения.
func (s *Setup) ConnState(c net.Conn, st http.ConnState) {
	if st == http.StateClosed || st == http.StateHijacked {
		raw := c
		if tc, ok := c.(*tls.Conn); ok {
			raw = tc.NetConn()
		}
		if st == http.StateClosed {
			s.served.Delete(raw)
		}
	}
}

// Forget — когда WebSocket (после Hijack) закрыт.
func (s *Setup) Forget(r *http.Request) {
	if c, ok := r.Context().Value(connKey{}).(net.Conn); ok {
		s.served.Delete(c)
	}
}

// CertHashes — хеши сертификатов, которые подписываются в challenge этого
// соединения: отданный сервером или все сертификаты прокси. Пусто — сервер
// не знает сертификат (unbound).
func (s *Setup) CertHashes(r *http.Request) [][]byte {
	if s.TLSConfig == nil {
		return s.proxyHashes
	}
	if c, ok := r.Context().Value(connKey{}).(net.Conn); ok {
		if h, ok := s.served.Load(c); ok {
			return [][]byte{h.([]byte)}
		}
	}
	return nil
}

// Fingerprint — SHA-256 сертификата: группы по 4 hex через «:».
func Fingerprint(der []byte) string {
	sum := sha256.Sum256(der)
	h := strings.ToUpper(hex.EncodeToString(sum[:]))
	var parts []string
	for i := 0; i < len(h); i += 4 {
		parts = append(parts, h[i:i+4])
	}
	return strings.Join(parts, ":")
}

func leafDER(path string) ([]byte, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	blk, _ := pem.Decode(b)
	if blk == nil || blk.Type != "CERTIFICATE" {
		return nil, errors.New("нет PEM CERTIFICATE")
	}
	return blk.Bytes, nil
}

// selfSigned читает или создаёт самоподписанный сертификат ECDSA P-256 на 10 лет.
func selfSigned(dir, host string) (tls.Certificate, error) {
	certPath, keyPath := filepath.Join(dir, "self-signed.crt"), filepath.Join(dir, "self-signed.key")
	if _, err := os.Stat(certPath); err == nil {
		return tls.LoadX509KeyPair(certPath, keyPath)
	} else if !errors.Is(err, fs.ErrNotExist) {
		return tls.Certificate{}, err
	}
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return tls.Certificate{}, err
	}
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return tls.Certificate{}, err
	}
	serial, _ := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 127))
	tpl := &x509.Certificate{
		SerialNumber: serial,
		Subject:      pkix.Name{CommonName: host, Organization: []string{"YeenLink"}},
		NotBefore:    time.Now().Add(-time.Hour),
		NotAfter:     time.Now().AddDate(10, 0, 0),
		KeyUsage:     x509.KeyUsageDigitalSignature,
		ExtKeyUsage:  []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
	}
	if ip := net.ParseIP(host); ip != nil {
		tpl.IPAddresses = []net.IP{ip}
	} else {
		tpl.DNSNames = []string{host}
	}
	der, err := x509.CreateCertificate(rand.Reader, tpl, tpl, &key.PublicKey, key)
	if err != nil {
		return tls.Certificate{}, err
	}
	kder, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return tls.Certificate{}, err
	}
	if err := os.WriteFile(keyPath, pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: kder}), 0o600); err != nil {
		return tls.Certificate{}, err
	}
	if err := os.WriteFile(certPath, pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der}), 0o644); err != nil {
		return tls.Certificate{}, err
	}
	return tls.LoadX509KeyPair(certPath, keyPath)
}

func (s *Setup) acme(ctx context.Context, c config.Config, log *slog.Logger) error {
	storage := &certmagic.FileStorage{Path: c.CertDir()}
	var cmCfg *certmagic.Config
	cache := certmagic.NewCache(certmagic.CacheOptions{
		GetConfigForCert: func(certmagic.Certificate) (*certmagic.Config, error) { return cmCfg, nil },
	})
	cmCfg = certmagic.New(cache, certmagic.Config{Storage: storage})
	issuer := certmagic.ACMEIssuer{
		CA:                   certmagic.LetsEncryptProductionCA,
		Email:                c.TLS.Email,
		Agreed:               true,
		DisableHTTPChallenge: c.TLS.HTTPPort == 0,
	}
	if c.TLS.ACMECA != "" {
		issuer.CA = c.TLS.ACMECA
	}
	if c.TLS.ACMERoots != "" {
		pool := x509.NewCertPool()
		b, err := os.ReadFile(c.TLS.ACMERoots)
		if err != nil || !pool.AppendCertsFromPEM(b) {
			return fmt.Errorf("tls.acme_roots %s: не прочитать PEM", c.TLS.ACMERoots)
		}
		issuer.TrustedRoots = pool
	}
	acme := certmagic.NewACMEIssuer(cmCfg, issuer)
	cmCfg.Issuers = []certmagic.Issuer{acme}
	if c.TLS.HTTPPort != 0 {
		s.HTTPChallenge = acme.HTTPChallengeHandler(redirectToHTTPS(c.Host))
	}
	log.Info("получаю сертификат Let's Encrypt", "host", c.Host, "ca", issuer.CA)
	if err := cmCfg.ManageSync(ctx, []string{c.Host}); err != nil {
		return fmt.Errorf("сертификат для %s: %w", c.Host, err)
	}
	base := cmCfg.TLSConfig()
	base.NextProtos = append([]string{"http/1.1"}, base.NextProtos...) // + acme-tls/1 от certmagic
	s.TLSConfig = s.wrap(base)
	return nil
}

// redirectToHTTPS ведёт на https://<host из конфига>/ — не на Host из запроса,
// чтобы порт 80 не стал открытым перенаправлением.
func redirectToHTTPS(host string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "https://"+host+"/", http.StatusMovedPermanently)
	})
}
