package main

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"yeenlink/server/pkg/codec"
	"yeenlink/server/pkg/identity"
)

// Векторы личности: одна фраза → одинаковые ключи, payload и подписи в Go и
// Dart. Ed25519 детерминирован (RFC 8032), поэтому подписи тоже совпадают.

type keyVector struct {
	Name             string `json:"name"`
	Entropy          string `json:"entropy"`
	Mnemonic         string `json:"mnemonic"`
	Seed             string `json:"seed"`
	MasterSeed       string `json:"master_seed"`
	MasterPub        string `json:"master_pub"`
	Fingerprint      string `json:"fingerprint"`
	ShortFingerprint string `json:"short_fingerprint"`
	NextPub          string `json:"next_pub"`
	NextKeyHash      string `json:"next_key_hash"`
}

type badMnemonic struct {
	Mnemonic string `json:"mnemonic"`
	Error    string `json:"error"` // word_count, unknown_word, checksum
	Index    int    `json:"index,omitempty"`
}

type deviceVector struct {
	Name string `json:"name"`
	Seed string `json:"seed"`
	Pub  string `json:"pub"`
}

type envelopeVector struct {
	Name    string          `json:"name"`
	T       string          `json:"t"`
	Signer  string          `json:"signer"` // имя ключа из keys/devices
	Payload json.RawMessage `json:"payload"`
	P       string          `json:"p"`
	K       string          `json:"k"`
	S       string          `json:"s"`
	Signed  string          `json:"signed"`
}

type badEnvelope struct {
	Name   string `json:"name"`
	Desc   string `json:"description"`
	Open   string `json:"open"`             // verify | profile | device_cert | revoke | devices
	Master string `json:"master,omitempty"` // для open с проверкой главного ключа
	Signed string `json:"signed"`
	Error  string `json:"error"`
}

const (
	created = uint64(1790000000000)
	updated = uint64(1790000123456)
)

func writeIdentity(dir string) error {
	zero, err := identity.FromEntropy(make([]byte, 16))
	if err != nil {
		return err
	}
	main, err := identity.FromEntropy(fixed("identity/main", 16))
	if err != nil {
		return err
	}
	keys := []keyVector{keyVec("zero", zero), keyVec("main", main)}

	dev1 := ed25519.NewKeyFromSeed(fixed("device/1", 32))
	dev2 := ed25519.NewKeyFromSeed(fixed("device/2", 32))
	devices := []deviceVector{devVec("device1", dev1), devVec("device2", dev2)}

	mpub := []byte(main.MasterPub())
	avatarSum := sha256.Sum256([]byte("yl-vector/avatar"))
	profile := identity.Profile{
		V: 1, Master: mpub, Seq: 3,
		Name:        "Пятнистый",
		About:       "Люблю ночные походы.\nИ кубики.",
		Avatar:      &identity.BlobRef{SHA256: avatarSum[:], Mime: "image/png", Size: 48213},
		BannerColor: "banner-2",
		Wall:        true,
		NextKeyHash: main.NextKeyHash[:],
		Updated:     updated,
	}
	minimal := identity.Profile{
		V: 1, Master: mpub, Seq: 1, Name: "Кривозуб", About: "",
		Wall: true, NextKeyHash: main.NextKeyHash[:], Updated: updated,
	}
	// ZWJ (U+200D) внутри эмодзи-семьи разрешён: 9 букв + 5 кодовых точек.
	emoji := minimal
	emoji.Name = "Пятнистый👨\u200D👩\u200D👧"
	cert := identity.DeviceCert{DevicePub: pub(dev1), Name: "Компьютер · Linux", Platform: "linux", Created: created}
	revoke := identity.Revoke{DevicePub: pub(dev2), Reason: "Потерян", At: created + 60_000}
	list := identity.Devices{Seq: 2, Active: [][]byte{pub(dev1)}, Revoked: [][]byte{pub(dev2)}}

	type item struct {
		name, t, signer string
		payload         any
		key             ed25519.PrivateKey
	}
	items := []item{
		{"profile", identity.TypeProfile, "main", profile, main.Master},
		{"profile_minimal", identity.TypeProfile, "main", minimal, main.Master},
		{"profile_emoji_zwj", identity.TypeProfile, "main", emoji, main.Master},
		{"device_cert", identity.TypeDeviceCert, "main", cert, main.Master},
		{"revoke", identity.TypeRevoke, "main", revoke, main.Master},
		{"devices", identity.TypeDevices, "main", list, main.Master},
	}
	var envs []envelopeVector
	signed := map[string]*identity.Signed{}
	for _, it := range items {
		s, err := identity.Sign(it.t, it.payload, it.key)
		if err != nil {
			return fmt.Errorf("%s: %w", it.name, err)
		}
		if err := checkOpenAs(s, it.t, mpub); err != nil {
			return fmt.Errorf("%s: %w", it.name, err)
		}
		enc, err := s.Encode()
		if err != nil {
			return err
		}
		pj, err := codec.ToJSON(s.P, codec.JSONOptions{})
		if err != nil {
			return err
		}
		signed[it.name] = s
		envs = append(envs, envelopeVector{
			Name: it.name, T: it.t, Signer: it.signer, Payload: pj,
			P: hx(s.P), K: hx(s.K), S: hx(s.S), Signed: hx(enc),
		})
	}

	bad, err := badEnvelopes(signed["profile"], main, dev1, profile)
	if err != nil {
		return err
	}

	badPhrases := []badMnemonic{
		{Mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon", Error: "word_count"},
		{Mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon", Error: "checksum"},
		{Mnemonic: "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon hyena", Error: "unknown_word", Index: 11},
	}
	for _, b := range badPhrases {
		_, err := identity.FromMnemonic(b.Mnemonic)
		if got := phraseErr(err); got != b.Error {
			return fmt.Errorf("фраза %q: ожидалась %s, получено %w", b.Mnemonic, b.Error, err)
		}
	}

	files := map[string]any{
		"keys.json": map[string]any{
			"description":  "Фраза → ключи (spec/identity.md). master_seed — закрытый ключ узла m/22860'/0'/0', next_pub — узла m/22860'/0'/1'.",
			"path":         "m/22860'/0'/i'",
			"keys":         keys,
			"devices":      devices,
			"bad_mnemonic": badPhrases,
		},
		"envelopes.json": map[string]any{
			"description": "Конверты Signed: payload (отладочный JSON) → p (CBOR) → s = Ed25519(\"yl-v1\" | t | p) → signed (CBOR конверта). Байты одинаковы в Go и Dart.",
			"envelopes":   envs,
			"bad":         bad,
		},
	}
	for name, v := range files {
		js, err := json.MarshalIndent(v, "", "  ")
		if err != nil {
			return err
		}
		if err := os.WriteFile(filepath.Join(dir, name), append(js, '\n'), 0o644); err != nil {
			return err
		}
	}
	return nil
}

func badEnvelopes(profile *identity.Signed, main *identity.Identity, dev ed25519.PrivateKey, p identity.Profile) ([]badEnvelope, error) {
	mpub := hx(main.MasterPub())
	var out []badEnvelope
	add := func(name, desc, open string, s *identity.Signed, want identity.ErrKind, master string) error {
		enc, err := s.Encode()
		if err != nil {
			return err
		}
		if got := identity.KindOf(checkOpenAs(s, open, main.MasterPub())); got != want {
			return fmt.Errorf("%s: ожидалась %s, получено %s", name, want, got)
		}
		out = append(out, badEnvelope{Name: name, Desc: desc, Open: open, Master: master, Signed: hx(enc), Error: string(want)})
		return nil
	}
	clone := func(f func(s *identity.Signed)) *identity.Signed {
		c := *profile
		c.P = append([]byte{}, profile.P...)
		c.K = append([]byte{}, profile.K...)
		c.S = append([]byte{}, profile.S...)
		f(&c)
		return &c
	}
	signProfile := func(mod func(p *identity.Profile), key ed25519.PrivateKey) *identity.Signed {
		q := p
		mod(&q)
		s, err := identity.Sign(identity.TypeProfile, q, key)
		if err != nil {
			panic(err)
		}
		return s
	}

	steps := []error{
		add("type_swap", "Подпись профиля, выданная за пост: t входит в подписываемые байты", "verify",
			clone(func(s *identity.Signed) { s.T = identity.TypePost }), identity.ErrBadSignature, ""),
		add("tampered_p", "Изменён последний байт payload", "verify",
			clone(func(s *identity.Signed) { s.P[len(s.P)-1] ^= 1 }), identity.ErrBadSignature, ""),
		add("foreign_k", "В k чужой ключ", "verify",
			clone(func(s *identity.Signed) { s.K = pub(dev) }), identity.ErrBadSignature, ""),
		add("unknown_type", "Неизвестный тип конверта", "verify",
			clone(func(s *identity.Signed) { s.T = "postcard" }), identity.ErrUnknownType, ""),
		add("wrong_type", "Профиль открыт как сертификат устройства", "device_cert",
			profile, identity.ErrWrongType, mpub),
		add("signer_mismatch", "Профиль с master = главный ключ, но подписан ключом устройства", "profile",
			signProfile(func(*identity.Profile) {}, dev), identity.ErrSignerMismatch, ""),
		add("name_empty", "Пустое имя", "profile",
			signProfile(func(q *identity.Profile) { q.Name = "" }, main.Master), identity.ErrBadPayload, ""),
		add("name_not_nfc", "Имя не в NFC: «Й» как И + U+0306", "profile",
			signProfile(func(q *identity.Profile) { q.Name = "И\u0306ож" }, main.Master), identity.ErrBadPayload, ""),
		add("name_control", "Управляющий символ U+0007 в имени", "profile",
			signProfile(func(q *identity.Profile) { q.Name = "Пят\u0007нистый" }, main.Master), identity.ErrBadPayload, ""),
		add("name_bidi_rlo", "Символ направления текста U+202E в имени", "profile",
			signProfile(func(q *identity.Profile) { q.Name = "\u202Eйытсинтяп" }, main.Master), identity.ErrBadPayload, ""),
		add("name_bidi_lrm", "Метка направления U+200E в имени", "profile",
			signProfile(func(q *identity.Profile) { q.Name = "Пятнистый\u200E" }, main.Master), identity.ErrBadPayload, ""),
		add("about_bidi_isolate", "Изолятор направления U+2067 в «о себе»", "profile",
			signProfile(func(q *identity.Profile) { q.About = "Ночью \u2067tset\u2069" }, main.Master), identity.ErrBadPayload, ""),
		add("name_too_long", "Имя из 33 символов", "profile",
			signProfile(func(q *identity.Profile) { q.Name = strings.Repeat("Ж", identity.NameMaxRunes+1) }, main.Master), identity.ErrBadPayload, ""),
		add("name_spaces", "Пробелы по краям имени", "profile",
			signProfile(func(q *identity.Profile) { q.Name = " Пятнистый" }, main.Master), identity.ErrBadPayload, ""),
	}
	for _, err := range steps {
		if err != nil {
			return nil, err
		}
	}
	return out, nil
}

func checkOpenAs(s *identity.Signed, open string, master []byte) error {
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
	default:
		err = fmt.Errorf("неизвестный open %q", open)
	}
	return err
}

func phraseErr(err error) string {
	var uw *identity.UnknownWordError
	switch {
	case err == nil:
		return ""
	case errors.Is(err, identity.ErrWordCount):
		return "word_count"
	case errors.Is(err, identity.ErrChecksum):
		return "checksum"
	case errors.As(err, &uw):
		return "unknown_word"
	}
	return err.Error()
}

func keyVec(name string, id *identity.Identity) keyVector {
	return keyVector{
		Name:             name,
		Entropy:          hx(id.Entropy),
		Mnemonic:         id.Mnemonic,
		Seed:             hx(identity.MnemonicToSeed(id.Mnemonic, "")),
		MasterSeed:       hx(id.Master.Seed()),
		MasterPub:        hx(id.MasterPub()),
		Fingerprint:      identity.Fingerprint(id.MasterPub()),
		ShortFingerprint: identity.ShortFingerprint(id.MasterPub()),
		NextPub:          hx(id.NextPub),
		NextKeyHash:      hx(id.NextKeyHash[:]),
	}
}

func devVec(name string, k ed25519.PrivateKey) deviceVector {
	return deviceVector{Name: name, Seed: hx(k.Seed()), Pub: hx(pub(k))}
}

func pub(k ed25519.PrivateKey) []byte { return []byte(k.Public().(ed25519.PublicKey)) }

func hx(b []byte) string { return hex.EncodeToString(b) }
