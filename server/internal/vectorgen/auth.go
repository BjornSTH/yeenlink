package main

import (
	"crypto/ed25519"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"

	"yeenlink/server/pkg/codec"
	"yeenlink/server/pkg/identity"
	"yeenlink/server/pkg/protocol"
)

// Векторы входа (spec/auth.md): подписываемые байты, подписи и кадры
// hello / challenge / auth, server_info и случаи проверки на клиенте и сервере.

type challengeCase struct {
	Name         string `json:"name"`
	Description  string `json:"description"`
	Challenge    string `json:"challenge"` // CBOR d кадра challenge
	Pinned       string `json:"pinned_server_pub"`
	SeenCertHash string `json:"seen_cert_hash,omitempty"` // пусто — без TLS
	Expect       string `json:"expect"`                   // ok | unbound | wrong_server | cert_not_signed
}

type authCase struct {
	Name        string `json:"name"`
	Description string `json:"description"`
	Sig         string `json:"sig"`
	DevicePub   string `json:"device_pub"`
	NowMs       uint64 `json:"now_ms"`
	Expect      string `json:"expect"` // ok | challenge_expired | bad_sig
}

func writeAuth(dir string) error {
	server := ed25519.NewKeyFromSeed(fixed("auth/server", 32))
	other := ed25519.NewKeyFromSeed(fixed("auth/other-server", 32))
	main, err := identity.FromEntropy(fixed("identity/main", 16))
	if err != nil {
		return err
	}
	stranger, err := identity.FromEntropy(fixed("auth/stranger", 16))
	if err != nil {
		return err
	}
	device := ed25519.NewKeyFromSeed(fixed("device/1", 32))
	spub := []byte(server.Public().(ed25519.PublicKey))

	cert := identity.DeviceCert{DevicePub: pub(device), Name: "Компьютер · Linux", Platform: "linux", Created: created}
	signedCert, err := identity.Sign(identity.TypeDeviceCert, cert, main.Master)
	if err != nil {
		return err
	}
	certBytes, err := signedCert.Encode()
	if err != nil {
		return err
	}
	foreignCert, err := identity.Sign(identity.TypeDeviceCert, cert, stranger.Master)
	if err != nil {
		return err
	}
	foreignCertBytes, err := foreignCert.Encode()
	if err != nil {
		return err
	}

	info, err := identity.Sign(identity.TypeServerInfo, identity.ServerInfo{
		V: 1, ServerPub: spub, Name: "Ночной привал", Version: "0.2.0",
	}, server)
	if err != nil {
		return err
	}
	infoBytes, err := info.Encode()
	if err != nil {
		return err
	}

	clientNonce := fixed("auth/client-nonce", 32)
	nonce := fixed("auth/nonce", 32)
	ts := uint64(1790000000000)
	tlsCert := fixed("auth/tls-cert-der", 300) // DER условный: важен только его SHA-256
	tlsCert2 := fixed("auth/tls-cert-der-rsa", 420)
	h1, h2 := protocol.CertHash(tlsCert), protocol.CertHash(tlsCert2)
	attacker := protocol.CertHash(fixed("auth/attacker-cert", 300))

	hello := protocol.Hello{
		Proto: protocol.Proto, MasterPub: main.MasterPub(), DevicePub: pub(device),
		DeviceCert: certBytes, ClientNonce: clientNonce,
	}
	helloResume := hello
	helloResume.Resume = &protocol.Resume{Session: fixed("auth/session", 16), LastEvent: 42}

	direct := protocol.SignChallenge(server, clientNonce, nonce, ts, [][]byte{h1})
	proxy := protocol.SignChallenge(server, clientNonce, nonce, ts, [][]byte{h1, h2})
	unbound := protocol.SignChallenge(server, clientNonce, nonce, ts, nil)
	impostor := protocol.SignChallenge(other, clientNonce, nonce, ts, [][]byte{h1})
	// Ключ сервера назван верный, но подпись чужим ключом.
	forged := impostor
	forged.ServerPub = spub

	authOK := protocol.SignAuth(device, nonce, spub, ts)
	authOther := protocol.SignAuth(ed25519.NewKeyFromSeed(fixed("device/2", 32)), nonce, spub, ts)

	enc := func(v any) (string, error) {
		b, err := codec.Marshal(v)
		return hx(b), err
	}
	encOrPanic := func(v any) string {
		s, err := enc(v)
		if err != nil {
			panic(err)
		}
		return s
	}

	ccases := []challengeCase{
		{"direct", "Прямой TLS: подпись по сертификату соединения", encOrPanic(direct), hx(spub), hx(h1), "ok"},
		{"proxy_second_cert", "Прокси отдаёт второй из двух сертификатов (RSA) — подпись в alt_sigs", encOrPanic(proxy), hx(spub), hx(h2), "ok"},
		{"unbound", "Прокси без tls.proxy_cert: подпись по нулевому хешу, клиент предупреждает", encOrPanic(unbound), hx(spub), hx(h1), "unbound"},
		{"cert_swapped", "Атакующий подставил свой сертификат TLS — хеш не подписан", encOrPanic(direct), hx(spub), hx(attacker), "cert_not_signed"},
		{"no_tls", "Соединение без TLS, а сервер подписал сертификат", encOrPanic(direct), hx(spub), "", "cert_not_signed"},
		{"other_server", "Другой сервер со своим ключом", encOrPanic(impostor), hx(spub), hx(h1), "wrong_server"},
		{"forged_sig", "Назван верный ключ, подпись чужим ключом", encOrPanic(forged), hx(spub), hx(h1), "cert_not_signed"},
	}
	for _, c := range ccases {
		if got := challengeOutcome(c, clientNonce); got != c.Expect {
			return fmt.Errorf("challenge %s: %s, ожидалось %s", c.Name, got, c.Expect)
		}
	}

	acases := []authCase{
		{"ok", "Подпись ключом устройства, challenge свежий", hx(authOK.Sig), hx(pub(device)), ts + 1000, "ok"},
		{"ttl_edge", "Ровно 30 с — ещё действует", hx(authOK.Sig), hx(pub(device)), ts + protocol.ChallengeTTLMs, "ok"},
		{"expired", "31 с — challenge истёк", hx(authOK.Sig), hx(pub(device)), ts + protocol.ChallengeTTLMs + 1000, "challenge_expired"},
		{"other_device", "Подписано другим устройством", hx(authOther.Sig), hx(pub(device)), ts + 1000, "bad_sig"},
	}
	for _, c := range acases {
		err := protocol.VerifyAuth(protocol.Auth{Sig: unhexMust(c.Sig)}, unhexMust(c.DevicePub), nonce, spub, ts, c.NowMs)
		if got := authOutcome(err); got != c.Expect {
			return fmt.Errorf("auth %s: %s, ожидалось %s", c.Name, got, c.Expect)
		}
	}

	out := map[string]any{
		"description": "Вход на сервер (spec/auth.md). Целые в подписываемых байтах — 8 байт big-endian.",
		"keys": map[string]any{
			"server_seed": hx(server.Seed()), "server_pub": hx(spub),
			"master_seed": hx(main.Master.Seed()), "master_pub": hx(main.MasterPub()),
			"device_seed": hx(device.Seed()), "device_pub": hx(pub(device)),
		},
		"client_nonce":        hx(clientNonce),
		"nonce":               hx(nonce),
		"ts":                  ts,
		"tls_cert_der":        hx(tlsCert),
		"tls_cert_hash":       hx(h1),
		"tls_cert2_der":       hx(tlsCert2),
		"tls_cert2_hash":      hx(h2),
		"server_preimage":     hx(protocol.ServerPreimage(clientNonce, nonce, ts, h1)),
		"server_sig":          hx(direct.ServerSig),
		"client_preimage":     hx(protocol.ClientPreimage(nonce, spub, ts)),
		"client_sig":          hx(authOK.Sig),
		"device_cert":         hx(certBytes),
		"device_cert_foreign": hx(foreignCertBytes),
		"server_info":         hx(infoBytes),
		"frame_hello":         frameHex("hello", 1, hello),
		"frame_hello_resume":  frameHex("hello", 1, helloResume),
		"frame_challenge":     frameHex("challenge", 1, direct),
		"frame_auth":          frameHex("auth", 2, authOK),
		"challenge_cases":     ccases,
		"auth_cases":          acases,
	}
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return err
	}
	js, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, "auth.json"), append(js, '\n'), 0o644)
}

func frameHex(op string, id uint64, d any) string {
	f, err := codec.NewFrame(op, codec.ID(id), d)
	if err != nil {
		panic(err)
	}
	b, err := f.Encode()
	if err != nil {
		panic(err)
	}
	return hx(b)
}

func challengeOutcome(c challengeCase, clientNonce []byte) string {
	var ch protocol.Challenge
	if err := codec.Unmarshal(unhexMust(c.Challenge), &ch); err != nil {
		return err.Error()
	}
	var seen []byte
	if c.SeenCertHash != "" {
		seen = unhexMust(c.SeenCertHash)
	}
	unbound, err := protocol.VerifyChallenge(ch, unhexMust(c.Pinned), clientNonce, seen)
	switch {
	case errors.Is(err, protocol.ErrWrongServer):
		return "wrong_server"
	case errors.Is(err, protocol.ErrCertNotSigned):
		return "cert_not_signed"
	case err != nil:
		return err.Error()
	case unbound:
		return "unbound"
	}
	return "ok"
}

func authOutcome(err error) string {
	switch {
	case err == nil:
		return "ok"
	case err.Error() == protocol.ErrBadSig:
		return "bad_sig"
	default:
		return protocol.ErrChallengeExpired
	}
}
