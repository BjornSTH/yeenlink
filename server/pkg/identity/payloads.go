package identity

import (
	"bytes"
	"crypto/ed25519"
	"strings"
	"unicode"
	"unicode/utf8"

	"golang.org/x/text/unicode/norm"
)

// Ограничения полей (docs/spec.md, «Форматы данных»; spec/identity.md).
const (
	NameMaxRunes       = 32
	AboutMaxRunes      = 300
	DeviceNameMaxRunes = 64
	ReasonMaxRunes     = 200
	AvatarMaxBytes     = 512 << 10
	BannerMaxBytes     = 1 << 20
	ProfileVersion     = 1
)

// Platforms — допустимые платформы устройства.
var Platforms = []string{"windows", "linux", "android", "macos"}

// BannerColors — допустимые имена цветов баннера (токены дизайн-системы).
// Неизвестное имя при показе заменяется на первое.
var BannerColors = []string{"banner-1", "banner-2", "banner-3", "banner-4", "banner-5"}

// BlobRef — картинка по хешу.
type BlobRef struct {
	SHA256 []byte `cbor:"sha256"`
	Mime   string `cbor:"mime"`
	Size   uint64 `cbor:"size"`
}

// Profile — payload t = "profile", подписывает master.
type Profile struct {
	V           uint64   `cbor:"v"`
	Master      []byte   `cbor:"master"`
	Seq         uint64   `cbor:"seq"`
	Name        string   `cbor:"name"`
	About       string   `cbor:"about"`
	Avatar      *BlobRef `cbor:"avatar,omitempty"`
	Banner      *BlobRef `cbor:"banner,omitempty"`
	BannerColor string   `cbor:"banner_color,omitempty"`
	Wall        bool     `cbor:"wall"`
	NextKeyHash []byte   `cbor:"next_key_hash"`
	Home        string   `cbor:"home,omitempty"`
	Updated     uint64   `cbor:"updated"`
}

// DeviceCert — payload t = "device_cert", подписывает master.
type DeviceCert struct {
	DevicePub []byte `cbor:"device_pub"`
	Name      string `cbor:"name"`
	Platform  string `cbor:"platform"`
	Created   uint64 `cbor:"created"`
}

// Revoke — payload t = "revoke", подписывает master.
type Revoke struct {
	DevicePub []byte `cbor:"device_pub"`
	Reason    string `cbor:"reason"`
	At        uint64 `cbor:"at"`
}

// Devices — payload t = "devices", подписывает master.
type Devices struct {
	Seq     uint64   `cbor:"seq"`
	Active  [][]byte `cbor:"active"`
	Revoked [][]byte `cbor:"revoked"`
}

// NormalizeText — канонический вид текстового поля: NFC и без пробелов по
// краям. Подписывается и проверяется именно он.
func NormalizeText(s string) string {
	return strings.TrimSpace(norm.NFC.String(s))
}

// checkText: уже нормализован, длина в кодовых точках, без управляющих
// символов (в многострочном поле разрешён только перевод строки).
func checkText(field, s string, minRunes, maxRunes int, multiline bool) error {
	if !utf8.ValidString(s) || s != NormalizeText(s) {
		return fail(ErrBadPayload, "%s не нормализовано (NFC, без пробелов по краям)", field)
	}
	n := utf8.RuneCountInString(s)
	if n < minRunes || n > maxRunes {
		return fail(ErrBadPayload, "%s: %d символов, нужно %d–%d", field, n, minRunes, maxRunes)
	}
	for _, r := range s {
		if unicode.IsControl(r) && (!multiline || r != '\n') {
			return fail(ErrBadPayload, "%s: управляющий символ U+%04X", field, r)
		}
	}
	return nil
}

func checkKey(field string, k []byte) error {
	if len(k) != ed25519.PublicKeySize {
		return fail(ErrBadPayload, "%s: %d байт, нужно 32", field, len(k))
	}
	return nil
}

func checkBlob(field string, b *BlobRef, maxSize uint64) error {
	if b == nil {
		return nil
	}
	if len(b.SHA256) != 32 {
		return fail(ErrBadPayload, "%s.sha256: нужно 32 байта", field)
	}
	if b.Mime != "image/png" && b.Mime != "image/webp" {
		return fail(ErrBadPayload, "%s.mime %q: нужен image/png или image/webp", field, b.Mime)
	}
	if b.Size == 0 || b.Size > maxSize {
		return fail(ErrBadPayload, "%s.size %d: нужно 1–%d", field, b.Size, maxSize)
	}
	return nil
}

func (p *Profile) validate() error {
	switch {
	case p.V != ProfileVersion:
		return fail(ErrBadPayload, "версия профиля %d", p.V)
	case p.Seq == 0:
		return fail(ErrBadPayload, "seq начинается с 1")
	case p.Updated == 0:
		return fail(ErrBadPayload, "нет updated")
	case p.Banner != nil && p.BannerColor != "":
		return fail(ErrBadPayload, "banner и banner_color вместе")
	case len(p.NextKeyHash) != 32:
		return fail(ErrBadPayload, "next_key_hash: нужно 32 байта")
	}
	if err := checkKey("master", p.Master); err != nil {
		return err
	}
	if err := checkText("name", p.Name, 1, NameMaxRunes, false); err != nil {
		return err
	}
	if err := checkText("about", p.About, 0, AboutMaxRunes, true); err != nil {
		return err
	}
	if p.BannerColor != "" {
		if err := checkText("banner_color", p.BannerColor, 1, 32, false); err != nil {
			return err
		}
	}
	if err := checkBlob("avatar", p.Avatar, AvatarMaxBytes); err != nil {
		return err
	}
	return checkBlob("banner", p.Banner, BannerMaxBytes)
}

func (d *DeviceCert) validate() error {
	if err := checkKey("device_pub", d.DevicePub); err != nil {
		return err
	}
	if err := checkText("name", d.Name, 1, DeviceNameMaxRunes, false); err != nil {
		return err
	}
	ok := false
	for _, p := range Platforms {
		ok = ok || p == d.Platform
	}
	if !ok {
		return fail(ErrBadPayload, "платформа %q", d.Platform)
	}
	if d.Created == 0 {
		return fail(ErrBadPayload, "нет created")
	}
	return nil
}

func (r *Revoke) validate() error {
	if err := checkKey("device_pub", r.DevicePub); err != nil {
		return err
	}
	if err := checkText("reason", r.Reason, 0, ReasonMaxRunes, false); err != nil {
		return err
	}
	if r.At == 0 {
		return fail(ErrBadPayload, "нет at")
	}
	return nil
}

func (d *Devices) validate() error {
	if d.Seq == 0 {
		return fail(ErrBadPayload, "seq начинается с 1")
	}
	seen := map[string]bool{}
	for _, list := range [][][]byte{d.Active, d.Revoked} {
		for _, k := range list {
			if err := checkKey("devices", k); err != nil {
				return err
			}
			if seen[string(k)] {
				return fail(ErrBadPayload, "ключ устройства повторяется")
			}
			seen[string(k)] = true
		}
	}
	return nil
}

// OpenProfile проверяет конверт профиля: подпись, поля и то, что подписал
// именно master из профиля.
func OpenProfile(s *Signed) (*Profile, error) {
	var p Profile
	if err := open(s, TypeProfile, &p); err != nil {
		return nil, err
	}
	if !bytes.Equal(s.K, p.Master) {
		return nil, fail(ErrSignerMismatch, "профиль подписан не своим главным ключом")
	}
	return &p, nil
}

// OpenDeviceCert проверяет сертификат устройства, подписанный master.
func OpenDeviceCert(s *Signed, master []byte) (*DeviceCert, error) {
	var d DeviceCert
	if err := openBy(s, TypeDeviceCert, &d, master); err != nil {
		return nil, err
	}
	return &d, nil
}

// OpenRevoke проверяет отзыв, подписанный master.
func OpenRevoke(s *Signed, master []byte) (*Revoke, error) {
	var r Revoke
	if err := openBy(s, TypeRevoke, &r, master); err != nil {
		return nil, err
	}
	return &r, nil
}

// OpenDevices проверяет список устройств, подписанный master.
func OpenDevices(s *Signed, master []byte) (*Devices, error) {
	var d Devices
	if err := openBy(s, TypeDevices, &d, master); err != nil {
		return nil, err
	}
	return &d, nil
}

func openBy(s *Signed, t string, v interface{ validate() error }, master []byte) error {
	if err := open(s, t, v); err != nil {
		return err
	}
	if !bytes.Equal(s.K, master) {
		return fail(ErrSignerMismatch, "%s подписан не главным ключом", t)
	}
	return nil
}
