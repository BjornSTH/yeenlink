// Package config — настройки сервера: файл TOML (/etc/yeenlink/ylsrv.toml),
// поверх него — флаги командной строки (spec/server.md, «Конфиг»).
package config

import (
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"

	"github.com/BurntSushi/toml"
)

// DefaultPath — где ylsrv ищет конфиг, если не указан --config.
const DefaultPath = "/etc/yeenlink/ylsrv.toml"

// Режимы TLS.
const (
	TLSACME       = "acme"        // Let's Encrypt (TLS-ALPN-01 и HTTP-01) через certmagic
	TLSFile       = "file"        // свой сертификат и ключ
	TLSSelfSigned = "self-signed" // создаётся сам, отпечаток печатается
	TLSProxy      = "proxy"       // TLS у nginx/Caddy впереди, сервер слушает без TLS
)

// TLS — сертификат.
type TLS struct {
	Mode string `toml:"mode"`
	// ACME.
	Email     string `toml:"email,omitempty"`
	ACMECA    string `toml:"acme_ca,omitempty"`    // адрес ACME (по умолчанию Let's Encrypt; в тестах — Pebble)
	ACMERoots string `toml:"acme_roots,omitempty"` // PEM корней для acme_ca (Pebble)
	HTTPPort  int    `toml:"http_port"`            // порт для HTTP-01; 0 — только TLS-ALPN-01
	// Свой файл.
	CertFile string `toml:"cert_file,omitempty"`
	KeyFile  string `toml:"key_file,omitempty"`
	// За прокси: сертификаты, которые отдаёт прокси (PEM) — их хеши подписываются
	// в challenge. Без них клиент предупредит, что подмена не исключена.
	ProxyCerts []string `toml:"proxy_cert,omitempty"`
}

// Config — все настройки.
type Config struct {
	Name    string `toml:"name"`     // название сервера
	DataDir string `toml:"data_dir"` // ключ сервера, база, ключ администратора, сертификаты
	Listen  string `toml:"listen"`   // адрес API и WebSocket
	Host    string `toml:"host"`     // домен или IP, под которым сервер виден снаружи
	TLS     TLS    `toml:"tls"`
	// TrustedProxies — адреса или сети, которым верим в X-Forwarded-For.
	TrustedProxies []string `toml:"trusted_proxies,omitempty"`
	// MemoryLimitMiB — мягкий предел памяти Go (GOMEMLIMIT); 0 — 80.
	MemoryLimitMiB int `toml:"memory_limit_mib"`
	// Codec — cbor или json (отладка).
	Codec string `toml:"codec"`
}

// Default — значения по умолчанию.
func Default() Config {
	return Config{
		DataDir:        "/var/lib/yeenlink",
		Listen:         ":443",
		TLS:            TLS{Mode: TLSACME, HTTPPort: 80},
		MemoryLimitMiB: 80,
		Codec:          "cbor",
	}
}

// Load читает файл поверх значений по умолчанию. Нет файла — ошибка
// os.ErrNotExist (её проверяет ylsrv init).
func Load(path string) (Config, error) {
	c := Default()
	md, err := toml.DecodeFile(path, &c)
	if err != nil {
		return c, err
	}
	if und := md.Undecoded(); len(und) > 0 {
		return c, fmt.Errorf("config: неизвестные ключи в %s: %v", path, und)
	}
	return c, nil
}

// Save записывает конфиг (для ylsrv init).
func Save(path string, c Config) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
		return err
	}
	f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	_, _ = fmt.Fprintln(f, "# Конфиг сервера YeenLink. Описание ключей — spec/server.md.")
	if err := toml.NewEncoder(f).Encode(c); err != nil {
		_ = f.Close()
		return err
	}
	return f.Close()
}

// Validate проверяет согласованность.
func (c Config) Validate() error {
	var errs []error
	if strings.TrimSpace(c.Name) == "" {
		errs = append(errs, errors.New("name: нужно название сервера"))
	}
	if c.DataDir == "" {
		errs = append(errs, errors.New("data_dir: пусто"))
	}
	if _, _, err := net.SplitHostPort(c.Listen); err != nil {
		errs = append(errs, fmt.Errorf("listen %q: %w", c.Listen, err))
	}
	if c.Codec != "cbor" && c.Codec != "json" {
		errs = append(errs, fmt.Errorf("codec %q: cbor или json", c.Codec))
	}
	switch c.TLS.Mode {
	case TLSACME:
		if c.Host == "" || net.ParseIP(c.Host) != nil {
			errs = append(errs, errors.New("tls.mode = acme: нужен домен в host (для IP-адреса — self-signed)"))
		}
	case TLSFile:
		if c.TLS.CertFile == "" || c.TLS.KeyFile == "" {
			errs = append(errs, errors.New("tls.mode = file: нужны cert_file и key_file"))
		}
	case TLSSelfSigned:
		if c.Host == "" {
			errs = append(errs, errors.New("tls.mode = self-signed: нужен host (домен или IP) для сертификата"))
		}
	case TLSProxy:
	default:
		errs = append(errs, fmt.Errorf("tls.mode %q: acme, file, self-signed или proxy", c.TLS.Mode))
	}
	return errors.Join(errs...)
}

// ServerKeyPath — ключ сервера (0600).
func (c Config) ServerKeyPath() string { return filepath.Join(c.DataDir, "server.key") }

// AdminTokenPath — ключ администратора (0600), пока им не воспользовались.
func (c Config) AdminTokenPath() string { return filepath.Join(c.DataDir, "admin-token") }

// DBPath — база SQLite.
func (c Config) DBPath() string { return filepath.Join(c.DataDir, "yeenlink.db") }

// CertDir — сертификаты (самоподписанный, certmagic).
func (c Config) CertDir() string { return filepath.Join(c.DataDir, "certs") }
