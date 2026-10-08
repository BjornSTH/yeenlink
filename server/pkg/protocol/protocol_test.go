package protocol_test

import (
	"bytes"
	"crypto/ed25519"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"testing"

	"yeenlink/server/pkg/codec"
	"yeenlink/server/pkg/identity"
	"yeenlink/server/pkg/protocol"
)

type vectors struct {
	Keys struct {
		ServerSeed string `json:"server_seed"`
		ServerPub  string `json:"server_pub"`
		MasterPub  string `json:"master_pub"`
		DeviceSeed string `json:"device_seed"`
		DevicePub  string `json:"device_pub"`
	} `json:"keys"`
	ClientNonce       string `json:"client_nonce"`
	Nonce             string `json:"nonce"`
	TS                uint64 `json:"ts"`
	TLSCertDER        string `json:"tls_cert_der"`
	TLSCertHash       string `json:"tls_cert_hash"`
	ServerPreimage    string `json:"server_preimage"`
	ServerSig         string `json:"server_sig"`
	ClientPreimage    string `json:"client_preimage"`
	ClientSig         string `json:"client_sig"`
	DeviceCert        string `json:"device_cert"`
	DeviceCertForeign string `json:"device_cert_foreign"`
	ServerInfo        string `json:"server_info"`
	FrameHello        string `json:"frame_hello"`
	FrameChallenge    string `json:"frame_challenge"`
	FrameAuth         string `json:"frame_auth"`
	ChallengeCases    []struct {
		Name, Challenge, Expect string
		Pinned                  string `json:"pinned_server_pub"`
		SeenCertHash            string `json:"seen_cert_hash"`
	} `json:"challenge_cases"`
	AuthCases []struct {
		Name, Sig, Expect string
		DevicePub         string `json:"device_pub"`
		NowMs             uint64 `json:"now_ms"`
	} `json:"auth_cases"`
}

func load(t *testing.T) vectors {
	t.Helper()
	b, err := os.ReadFile("../../../testdata/vectors/auth/auth.json")
	if err != nil {
		t.Fatal(err)
	}
	var v vectors
	if err := json.Unmarshal(b, &v); err != nil {
		t.Fatal(err)
	}
	return v
}

func h(t *testing.T, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestPreimagesAndSignatures(t *testing.T) {
	v := load(t)
	server := ed25519.NewKeyFromSeed(h(t, v.Keys.ServerSeed))
	device := ed25519.NewKeyFromSeed(h(t, v.Keys.DeviceSeed))
	certHash := protocol.CertHash(h(t, v.TLSCertDER))
	if hex.EncodeToString(certHash) != v.TLSCertHash {
		t.Fatal("хеш сертификата")
	}
	sp := protocol.ServerPreimage(h(t, v.ClientNonce), h(t, v.Nonce), v.TS, certHash)
	if hex.EncodeToString(sp) != v.ServerPreimage {
		t.Fatalf("server preimage %x", sp)
	}
	c := protocol.SignChallenge(server, h(t, v.ClientNonce), h(t, v.Nonce), v.TS, [][]byte{certHash})
	if hex.EncodeToString(c.ServerSig) != v.ServerSig {
		t.Fatal("server_sig")
	}
	cp := protocol.ClientPreimage(h(t, v.Nonce), h(t, v.Keys.ServerPub), v.TS)
	if hex.EncodeToString(cp) != v.ClientPreimage {
		t.Fatalf("client preimage %x", cp)
	}
	a := protocol.SignAuth(device, h(t, v.Nonce), h(t, v.Keys.ServerPub), v.TS)
	if hex.EncodeToString(a.Sig) != v.ClientSig {
		t.Fatal("client sig")
	}
}

func TestFrames(t *testing.T) {
	v := load(t)
	for name, frame := range map[string]string{"hello": v.FrameHello, "challenge": v.FrameChallenge, "auth": v.FrameAuth} {
		f, err := codec.DecodeFrame(h(t, frame))
		if err != nil || f.Op != name {
			t.Fatalf("%s: %v %v", name, f, err)
		}
		enc, _ := f.Encode()
		if !bytes.Equal(enc, h(t, frame)) {
			t.Fatalf("%s перекодирован иначе", name)
		}
	}
	f, _ := codec.DecodeFrame(h(t, v.FrameHello))
	var hello protocol.Hello
	if err := f.DecodeD(&hello); err != nil {
		t.Fatal(err)
	}
	// Сертификат устройства в hello — конверт, подписанный главным ключом.
	s, err := identity.DecodeSigned(hello.DeviceCert)
	if err != nil {
		t.Fatal(err)
	}
	cert, err := identity.OpenDeviceCert(s, hello.MasterPub)
	if err != nil || !bytes.Equal(cert.DevicePub, hello.DevicePub) {
		t.Fatalf("сертификат: %v", err)
	}
	foreign, _ := identity.DecodeSigned(h(t, v.DeviceCertForeign))
	if _, err := identity.OpenDeviceCert(foreign, hello.MasterPub); identity.KindOf(err) != identity.ErrSignerMismatch {
		t.Fatalf("чужой сертификат: %v", err)
	}
	info, _ := identity.DecodeSigned(h(t, v.ServerInfo))
	si, err := identity.OpenServerInfo(info)
	if err != nil || hex.EncodeToString(si.ServerPub) != v.Keys.ServerPub {
		t.Fatalf("server_info: %v", err)
	}
}

func TestChallengeCases(t *testing.T) {
	v := load(t)
	for _, c := range v.ChallengeCases {
		var ch protocol.Challenge
		if err := codec.Unmarshal(h(t, c.Challenge), &ch); err != nil {
			t.Fatal(err)
		}
		var seen []byte
		if c.SeenCertHash != "" {
			seen = h(t, c.SeenCertHash)
		}
		unbound, err := protocol.VerifyChallenge(ch, h(t, c.Pinned), h(t, v.ClientNonce), seen)
		got := "ok"
		switch {
		case errors.Is(err, protocol.ErrWrongServer):
			got = "wrong_server"
		case errors.Is(err, protocol.ErrCertNotSigned):
			got = "cert_not_signed"
		case err != nil:
			got = err.Error()
		case unbound:
			got = "unbound"
		}
		if got != c.Expect {
			t.Errorf("%s: %s, ожидалось %s", c.Name, got, c.Expect)
		}
	}
}

func TestAuthCases(t *testing.T) {
	v := load(t)
	for _, c := range v.AuthCases {
		err := protocol.VerifyAuth(protocol.Auth{Sig: h(t, c.Sig)}, h(t, c.DevicePub), h(t, v.Nonce), h(t, v.Keys.ServerPub), v.TS, c.NowMs)
		got := "ok"
		if err != nil {
			got = protocol.ErrChallengeExpired
			if err.Error() == protocol.ErrBadSig {
				got = protocol.ErrBadSig
			}
		}
		if got != c.Expect {
			t.Errorf("%s: %s, ожидалось %s", c.Name, got, c.Expect)
		}
	}
}
