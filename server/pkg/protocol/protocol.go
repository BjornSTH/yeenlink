// Package protocol — кадры и подписи входа на сервер (spec/auth.md), общие
// для сервера, тестового клиента и векторов. Та же логика на Dart —
// client/lib/core/protocol.
package protocol

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"fmt"
)

// Proto — версия протокола в hello.
const Proto = 1

// Имена операций фазы 2.
const (
	OpHello        = "hello"
	OpChallenge    = "challenge"
	OpAuth         = "auth"
	OpReady        = "ready"
	OpResumed      = "resumed"
	OpAdminClaim   = "admin.claim"
	OpProfilePush  = "profile.push"
	OpDevicesPush  = "devices.push"
	OpRevokePush   = "revoke.push"
	OpServerUpdate = "server.update"
	OpMemberUpdate = "member.update"
)

// Коды ошибок в e.code.
const (
	ErrProto            = "proto"
	ErrBadFrame         = "bad_frame"
	ErrBadCert          = "bad_cert"
	ErrDeviceRevoked    = "device_revoked"
	ErrBadSig           = "bad_sig"
	ErrChallengeExpired = "challenge_expired"
	ErrNotAuthenticated = "not_authenticated"
	ErrUnknownOp        = "unknown_op"
	ErrRateLimited      = "rate_limited"
	ErrBadToken         = "bad_token"
	ErrStale            = "stale" // профиль или список устройств с не бо́льшим seq
	ErrBadPayload       = "bad_payload"
	ErrReplaced         = "replaced" // сессию продолжили в другом соединении
)

// Сроки.
const (
	ChallengeTTLMs   = 30_000
	ResumeWindowMs   = 5 * 60_000
	NonceSize        = 32
	SessionIDSize    = 16
	MaxFrameBytes    = 256 << 10
	PingIntervalMs   = 30_000
	IdleTimeoutMs    = 90_000
	ClaimLimitPerMin = 5
)

const (
	serverPrefix = "yl-server-v1"
	clientPrefix = "yl-auth-v1"
)

// Resume — продолжение сессии в hello.
type Resume struct {
	Session   []byte `cbor:"session"`
	LastEvent uint64 `cbor:"last_event"`
}

// Hello — первый кадр клиента. DeviceCert — CBOR конверта Signed как есть.
type Hello struct {
	Proto       uint64  `cbor:"proto"`
	MasterPub   []byte  `cbor:"master_pub"`
	DevicePub   []byte  `cbor:"device_pub"`
	DeviceCert  []byte  `cbor:"device_cert"`
	ClientNonce []byte  `cbor:"client_nonce"`
	Resume      *Resume `cbor:"resume,omitempty"`
}

// AltSig — подпись для другого сертификата, который может отдавать прокси.
type AltSig struct {
	CertHash []byte `cbor:"h"`
	Sig      []byte `cbor:"s"`
}

// Challenge — ответ сервера на hello. ServerSig — подпись для сертификата
// этого соединения (или первого из tls.proxy_cert); AltSigs — для остальных
// сертификатов прокси; Unbound — сервер не знает сертификат (подпись по
// нулевому хешу), клиент предупреждает.
type Challenge struct {
	Nonce     []byte   `cbor:"nonce"`
	ServerPub []byte   `cbor:"server_pub"`
	TS        uint64   `cbor:"ts"`
	ServerSig []byte   `cbor:"server_sig"`
	AltSigs   []AltSig `cbor:"alt_sigs,omitempty"`
	Unbound   bool     `cbor:"unbound,omitempty"`
}

// Auth — подпись клиента.
type Auth struct {
	Sig []byte `cbor:"sig"`
}

// ZeroCertHash — хеш «сертификат неизвестен» (прокси без tls.proxy_cert,
// соединение без TLS в отладке).
var ZeroCertHash = make([]byte, 32)

// CertHash — SHA-256 DER-сертификата TLS.
func CertHash(der []byte) []byte {
	h := sha256.Sum256(der)
	return h[:]
}

func be64(v uint64) []byte { return binary.BigEndian.AppendUint64(nil, v) }

func cat(parts ...[]byte) []byte {
	var out []byte
	for _, p := range parts {
		out = append(out, p...)
	}
	return out
}

// ServerPreimage — "yl-server-v1" | client_nonce | nonce | ts | cert_hash.
func ServerPreimage(clientNonce, nonce []byte, ts uint64, certHash []byte) []byte {
	return cat([]byte(serverPrefix), clientNonce, nonce, be64(ts), certHash)
}

// ClientPreimage — "yl-auth-v1" | nonce | server_pub | ts.
func ClientPreimage(nonce, serverPub []byte, ts uint64) []byte {
	return cat([]byte(clientPrefix), nonce, serverPub, be64(ts))
}

// SignChallenge подписывает challenge для каждого известного сертификата:
// первый — в ServerSig, остальные — в AltSigs. Без сертификатов — Unbound.
func SignChallenge(key ed25519.PrivateKey, clientNonce, nonce []byte, ts uint64, certHashes [][]byte) Challenge {
	c := Challenge{Nonce: nonce, ServerPub: key.Public().(ed25519.PublicKey), TS: ts}
	if len(certHashes) == 0 {
		c.Unbound = true
		c.ServerSig = ed25519.Sign(key, ServerPreimage(clientNonce, nonce, ts, ZeroCertHash))
		return c
	}
	c.ServerSig = ed25519.Sign(key, ServerPreimage(clientNonce, nonce, ts, certHashes[0]))
	for _, h := range certHashes[1:] {
		c.AltSigs = append(c.AltSigs, AltSig{CertHash: h, Sig: ed25519.Sign(key, ServerPreimage(clientNonce, nonce, ts, h))})
	}
	return c
}

// Ошибки проверки challenge на стороне клиента.
var (
	ErrWrongServer   = errors.New("protocol: это не тот сервер — ключ не совпадает с закреплённым")
	ErrCertNotSigned = errors.New("protocol: сертификат TLS не подписан ключом сервера — возможна подмена")
)

// VerifyChallenge — проверка клиента: ключ сервера тот, что закреплён, и
// подпись покрывает сертификат, который клиент видит сам (seenCertHash; nil —
// соединение без TLS). Возвращает unbound = true, если сервер не знает свой
// сертификат и защиты от подмены нет — тогда клиент предупреждает.
func VerifyChallenge(c Challenge, pinnedServerPub, clientNonce, seenCertHash []byte) (unbound bool, err error) {
	if !equal(c.ServerPub, pinnedServerPub) {
		return false, ErrWrongServer
	}
	pub := ed25519.PublicKey(c.ServerPub)
	if len(pub) != ed25519.PublicKeySize {
		return false, ErrWrongServer
	}
	if c.Unbound {
		if !ed25519.Verify(pub, ServerPreimage(clientNonce, c.Nonce, c.TS, ZeroCertHash), c.ServerSig) {
			return false, ErrWrongServer
		}
		return true, nil
	}
	if seenCertHash == nil {
		return false, ErrCertNotSigned
	}
	try := func(h, sig []byte) bool {
		return equal(h, seenCertHash) && ed25519.Verify(pub, ServerPreimage(clientNonce, c.Nonce, c.TS, h), sig)
	}
	if try(seenCertHash, c.ServerSig) {
		return false, nil
	}
	for _, a := range c.AltSigs {
		if try(a.CertHash, a.Sig) {
			return false, nil
		}
	}
	return false, ErrCertNotSigned
}

// SignAuth — подпись клиента ключом устройства.
func SignAuth(device ed25519.PrivateKey, nonce, serverPub []byte, ts uint64) Auth {
	return Auth{Sig: ed25519.Sign(device, ClientPreimage(nonce, serverPub, ts))}
}

// VerifyAuth — проверка сервера: подпись устройства и свежесть challenge.
func VerifyAuth(a Auth, devicePub, nonce, serverPub []byte, ts, nowMs uint64) error {
	if nowMs > ts+ChallengeTTLMs {
		return fmt.Errorf("%s: challenge старше %d мс", ErrChallengeExpired, ChallengeTTLMs)
	}
	if len(devicePub) != ed25519.PublicKeySize || !ed25519.Verify(devicePub, ClientPreimage(nonce, serverPub, ts), a.Sig) {
		return errors.New(ErrBadSig)
	}
	return nil
}

func equal(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	var d byte
	for i := range a {
		d |= a[i] ^ b[i]
	}
	return d == 0
}
