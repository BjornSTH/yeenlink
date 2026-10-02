package identity_test

import (
	"bytes"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"strings"
	"testing"

	"golang.org/x/text/unicode/norm"

	"yeenlink/server/pkg/codec"
	"yeenlink/server/pkg/identity"
)

const vectors = "../../../testdata/vectors/"

func readJSON(t *testing.T, path string, v any) {
	t.Helper()
	b, err := os.ReadFile(vectors + path)
	if err != nil {
		t.Fatal(err)
	}
	if err := json.Unmarshal(b, v); err != nil {
		t.Fatal(err)
	}
}

func unhex(t *testing.T, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(s)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestWordlistIsOfficial(t *testing.T) {
	b, err := os.ReadFile("english.txt")
	if err != nil {
		t.Fatal(err)
	}
	sum := sha256.Sum256(b)
	if got := hex.EncodeToString(sum[:]); got != "2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda" {
		t.Fatalf("список BIP39 не официальный: %s", got)
	}
	if len(identity.Wordlist) != 2048 {
		t.Fatalf("слов %d", len(identity.Wordlist))
	}
}

// Официальные векторы trezor/python-mnemonic: энтропия → фраза → seed.
func TestBIP39Official(t *testing.T) {
	var v struct {
		Passphrase string     `json:"passphrase"`
		English    [][]string `json:"english"`
	}
	readJSON(t, "bip39/vectors.json", &v)
	for _, c := range v.English {
		entropy, mnemonic, seed := unhex(t, c[0]), c[1], c[2]
		m, err := identity.EntropyToMnemonic(entropy)
		if err != nil || m != mnemonic {
			t.Fatalf("энтропия %s → %q, ожидалось %q (%v)", c[0], m, mnemonic, err)
		}
		e, err := identity.MnemonicToEntropy(mnemonic)
		if err != nil || !bytes.Equal(e, entropy) {
			t.Fatalf("фраза %q → %x (%v)", mnemonic, e, err)
		}
		if got := hex.EncodeToString(identity.MnemonicToSeed(mnemonic, v.Passphrase)); got != seed {
			t.Fatalf("seed %q: %s", mnemonic, got)
		}
	}
}

// Официальные векторы SLIP-0010 для ed25519.
func TestSLIP10Official(t *testing.T) {
	var v struct {
		Vectors []struct {
			Seed   string `json:"seed"`
			Chains []struct {
				Path      string `json:"path"`
				ChainCode string `json:"chain_code"`
				Private   string `json:"private"`
				Public    string `json:"public"`
			} `json:"chains"`
		} `json:"vectors"`
	}
	readJSON(t, "slip10/ed25519.json", &v)
	n := 0
	for _, vec := range v.Vectors {
		for _, c := range vec.Chains {
			path, err := identity.ParsePath(c.Path)
			if err != nil {
				t.Fatal(err)
			}
			node, err := identity.DerivePath(unhex(t, vec.Seed), path)
			if err != nil {
				t.Fatal(err)
			}
			pub := ed25519.NewKeyFromSeed(node.Key[:]).Public().(ed25519.PublicKey)
			if hex.EncodeToString(node.ChainCode[:]) != c.ChainCode ||
				hex.EncodeToString(node.Key[:]) != c.Private ||
				"00"+hex.EncodeToString(pub) != c.Public {
				t.Fatalf("%s от %s не совпал", c.Path, vec.Seed)
			}
			n++
		}
	}
	if n != 12 {
		t.Fatalf("проверено цепочек %d, ожидалось 12", n)
	}
}

func TestSLIP10RejectsNormalIndex(t *testing.T) {
	if _, err := identity.MasterNode(make([]byte, 16)).Child(0); err == nil {
		t.Fatal("ed25519 не должен выводить не-hardened индекс")
	}
}

// RFC 8032, раздел 7.1, тест 1 — та же проверка есть в Dart.
func TestEd25519RFC8032(t *testing.T) {
	key := ed25519.NewKeyFromSeed(unhex(t, "9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60"))
	sig := ed25519.Sign(key, nil)
	if hex.EncodeToString(sig) != "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b" {
		t.Fatalf("подпись %x", sig)
	}
}

type keyVector struct {
	Name, Entropy, Mnemonic, Seed string
	MasterSeed                    string `json:"master_seed"`
	MasterPub                     string `json:"master_pub"`
	Fingerprint                   string
	ShortFingerprint              string `json:"short_fingerprint"`
	NextPub                       string `json:"next_pub"`
	NextKeyHash                   string `json:"next_key_hash"`
}

type keysFile struct {
	Keys    []keyVector `json:"keys"`
	Devices []struct {
		Name, Seed, Pub string
	} `json:"devices"`
	BadMnemonic []struct {
		Mnemonic, Error string
		Index           int
	} `json:"bad_mnemonic"`
}

func TestIdentityKeys(t *testing.T) {
	var f keysFile
	readJSON(t, "identity/keys.json", &f)
	for _, k := range f.Keys {
		id, err := identity.FromMnemonic(strings.ToUpper("  " + k.Mnemonic + " "))
		if err != nil {
			t.Fatalf("%s: %v", k.Name, err)
		}
		checks := map[string][2]string{
			"entropy":       {hex.EncodeToString(id.Entropy), k.Entropy},
			"seed":          {hex.EncodeToString(identity.MnemonicToSeed(id.Mnemonic, "")), k.Seed},
			"master_seed":   {hex.EncodeToString(id.Master.Seed()), k.MasterSeed},
			"master_pub":    {hex.EncodeToString(id.MasterPub()), k.MasterPub},
			"fingerprint":   {identity.Fingerprint(id.MasterPub()), k.Fingerprint},
			"short":         {identity.ShortFingerprint(id.MasterPub()), k.ShortFingerprint},
			"next_pub":      {hex.EncodeToString(id.NextPub), k.NextPub},
			"next_key_hash": {hex.EncodeToString(id.NextKeyHash[:]), k.NextKeyHash},
		}
		for field, c := range checks {
			if c[0] != c[1] {
				t.Errorf("%s.%s: %s, ожидалось %s", k.Name, field, c[0], c[1])
			}
		}
	}
	for _, d := range f.Devices {
		pub := ed25519.NewKeyFromSeed(unhex(t, d.Seed)).Public().(ed25519.PublicKey)
		if hex.EncodeToString(pub) != d.Pub {
			t.Errorf("%s: ключ устройства не совпал", d.Name)
		}
	}
	for _, b := range f.BadMnemonic {
		_, err := identity.FromMnemonic(b.Mnemonic)
		var uw *identity.UnknownWordError
		got := map[bool]string{true: "word_count"}[errors.Is(err, identity.ErrWordCount)]
		if errors.Is(err, identity.ErrChecksum) {
			got = "checksum"
		}
		if errors.As(err, &uw) {
			got = "unknown_word"
			if uw.Index != b.Index {
				t.Errorf("%q: слово %d, ожидалось %d", b.Mnemonic, uw.Index, b.Index)
			}
		}
		if got != b.Error {
			t.Errorf("%q: %v, ожидалось %s", b.Mnemonic, err, b.Error)
		}
	}
}

type envelopesFile struct {
	Envelopes []struct {
		Name, T, Signer string
		Payload         json.RawMessage
		P, K, S, Signed string
	} `json:"envelopes"`
	Bad []struct {
		Name, Open, Master, Signed, Error string
	} `json:"bad"`
}

func TestIdentityEnvelopes(t *testing.T) {
	var keys keysFile
	readJSON(t, "identity/keys.json", &keys)
	signers := map[string]ed25519.PrivateKey{}
	for _, k := range keys.Keys {
		signers[k.Name] = ed25519.NewKeyFromSeed(unhex(t, k.MasterSeed))
	}
	var f envelopesFile
	readJSON(t, "identity/envelopes.json", &f)
	if len(f.Envelopes) == 0 || len(f.Bad) == 0 {
		t.Fatal("векторы пусты")
	}
	for _, e := range f.Envelopes {
		t.Run(e.Name, func(t *testing.T) {
			p, err := codec.FromJSON(e.Payload)
			if err != nil {
				t.Fatal(err)
			}
			if hex.EncodeToString(p) != e.P {
				t.Fatalf("p из payload: %x", p)
			}
			s, err := identity.SignBytes(e.T, p, signers[e.Signer])
			if err != nil {
				t.Fatal(err)
			}
			if hex.EncodeToString(s.K) != e.K || hex.EncodeToString(s.S) != e.S {
				t.Fatalf("подпись не совпала: %x", s.S)
			}
			enc, err := s.Encode()
			if err != nil || hex.EncodeToString(enc) != e.Signed {
				t.Fatalf("конверт не совпал: %x (%v)", enc, err)
			}
			dec, err := identity.DecodeSigned(unhex(t, e.Signed))
			if err != nil {
				t.Fatal(err)
			}
			if err := openAs(dec, e.T, dec.K); err != nil {
				t.Fatalf("проверка: %v", err)
			}
		})
	}
	for _, b := range f.Bad {
		t.Run("bad_"+b.Name, func(t *testing.T) {
			s, err := identity.DecodeSigned(unhex(t, b.Signed))
			if err != nil {
				t.Fatal(err)
			}
			master, _ := hex.DecodeString(b.Master)
			if got := identity.KindOf(openAs(s, b.Open, master)); string(got) != b.Error {
				t.Fatalf("ошибка %q, ожидалась %q", got, b.Error)
			}
		})
	}
}

func openAs(s *identity.Signed, open string, master []byte) error {
	var err error
	switch open {
	case "verify":
		err = s.Verify()
	case identity.TypeProfile:
		_, err = identity.OpenProfile(s)
	case identity.TypeDeviceCert:
		_, err = identity.OpenDeviceCert(s, master)
	case identity.TypeRevoke:
		_, err = identity.OpenRevoke(s, master)
	case identity.TypeDevices:
		_, err = identity.OpenDevices(s, master)
	}
	return err
}

// Подписываемые байты "yl-v1" | t | p однозначны, только пока ни один тип
// не начинается с другого.
func TestTypesArePrefixFree(t *testing.T) {
	for _, a := range identity.Types {
		for _, b := range identity.Types {
			if a != b && strings.HasPrefix(b, a) {
				t.Fatalf("тип %q начинается с %q — подписи станут неоднозначными", b, a)
			}
		}
	}
}

func TestNormalizeText(t *testing.T) {
	if got := identity.NormalizeText("  Йож \n"); got != "Йож" {
		t.Fatalf("%q", got)
	}
}

// Версия Unicode в нормализации NFC записана в spec/identity.md: если таблицы
// x/text сменятся (например, с Go 1.27), обновите спецификацию.
func TestUnicodeVersionDocumented(t *testing.T) {
	if norm.Version != "15.0.0" {
		t.Fatalf("x/text/unicode/norm теперь Unicode %s — обновите spec/identity.md", norm.Version)
	}
}

func TestBidiControls(t *testing.T) {
	for _, r := range []rune{0x202A, 0x202E, 0x2066, 0x2069, 0x200E, 0x200F} {
		if !identity.IsBidiControl(r) {
			t.Errorf("U+%04X должен быть запрещён", r)
		}
	}
	for _, r := range []rune{0x200D, 0x2029, 0x2065, 0x206A, 'a'} {
		if identity.IsBidiControl(r) {
			t.Errorf("U+%04X не должен быть запрещён", r)
		}
	}
}
