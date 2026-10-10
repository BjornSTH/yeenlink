package identity

import (
	"crypto/ed25519"
	"errors"
	"fmt"

	"yeenlink/server/pkg/codec"
)

// Типы подписанных конвертов (поле t). Ни один не начинается с другого —
// подписываемые байты "yl-v1" | t | p склеиваются без разделителя, и это
// условие делает склейку однозначной (проверяется тестом).
const (
	TypeProfile    = "profile"
	TypePost       = "post"
	TypeDeviceCert = "device_cert"
	TypeRevoke     = "revoke"
	TypeDevices    = "devices"
	TypeAddresses  = "addresses"
	TypeInvite     = "invite"
	TypeServerInfo = "server_info"
)

// Types — все известные типы.
var Types = []string{TypeProfile, TypePost, TypeDeviceCert, TypeRevoke, TypeDevices, TypeAddresses, TypeInvite, TypeServerInfo}

const signPrefix = "yl-v1"

// ErrKind — категория ошибки проверки. Те же строки у Dart и в векторах.
type ErrKind string

// Категории ошибок проверки конверта и payload.
const (
	ErrUnknownType    ErrKind = "unknown_type"
	ErrWrongType      ErrKind = "wrong_type"
	ErrBadKey         ErrKind = "bad_key"
	ErrBadSignature   ErrKind = "bad_signature"
	ErrBadPayload     ErrKind = "bad_payload"
	ErrSignerMismatch ErrKind = "signer_mismatch"
)

// Error — ошибка проверки с категорией.
type Error struct {
	Kind ErrKind
	Msg  string
}

func (e *Error) Error() string { return fmt.Sprintf("identity: %s: %s", e.Kind, e.Msg) }

// KindOf возвращает категорию ошибки или пустую строку.
func KindOf(err error) ErrKind {
	var e *Error
	if errors.As(err, &e) {
		return e.Kind
	}
	return ""
}

func fail(kind ErrKind, format string, args ...any) error {
	return &Error{Kind: kind, Msg: fmt.Sprintf(format, args...)}
}

// Signed — подписанный конверт. P — CBOR-байты payload: кодируются один
// раз при подписи и дальше никогда не пересобираются.
type Signed struct {
	T string `cbor:"t"`
	P []byte `cbor:"p"`
	K []byte `cbor:"k"`
	S []byte `cbor:"s"`
}

// Preimage — подписываемые байты: "yl-v1" | t | p.
func Preimage(t string, p []byte) []byte {
	out := make([]byte, 0, len(signPrefix)+len(t)+len(p))
	out = append(out, signPrefix...)
	out = append(out, t...)
	return append(out, p...)
}

// Sign кодирует payload в CBOR и подписывает.
func Sign(t string, payload any, key ed25519.PrivateKey) (*Signed, error) {
	p, err := codec.Marshal(payload)
	if err != nil {
		return nil, err
	}
	return SignBytes(t, p, key)
}

// SignBytes подписывает уже закодированный payload.
func SignBytes(t string, p []byte, key ed25519.PrivateKey) (*Signed, error) {
	if !knownType(t) {
		return nil, fail(ErrUnknownType, "тип %q", t)
	}
	return &Signed{
		T: t,
		P: append([]byte{}, p...),
		K: append([]byte{}, key.Public().(ed25519.PublicKey)...),
		S: ed25519.Sign(key, Preimage(t, p)),
	}, nil
}

// Verify проверяет тип, ключ, подпись и то, что p — корректный CBOR-словарь.
// Смысл payload проверяют Open* для конкретного типа.
func (s *Signed) Verify() error {
	if !knownType(s.T) {
		return fail(ErrUnknownType, "тип %q", s.T)
	}
	if len(s.K) != ed25519.PublicKeySize {
		return fail(ErrBadKey, "ключ %d байт", len(s.K))
	}
	if len(s.S) != ed25519.SignatureSize || !ed25519.Verify(s.K, Preimage(s.T, s.P), s.S) {
		return fail(ErrBadSignature, "подпись не сходится")
	}
	v, err := codec.Decode(s.P)
	if err != nil {
		return fail(ErrBadPayload, "%v", err)
	}
	if _, ok := v.(map[string]any); !ok {
		return fail(ErrBadPayload, "payload не словарь")
	}
	return nil
}

// Encode кодирует конверт в CBOR.
func (s *Signed) Encode() ([]byte, error) { return codec.Marshal(s) }

// DecodeSigned разбирает конверт (без проверки подписи — для неё Verify).
func DecodeSigned(data []byte) (*Signed, error) {
	var s Signed
	if err := codec.Unmarshal(data, &s); err != nil {
		return nil, fail(ErrBadPayload, "конверт: %v", err)
	}
	return &s, nil
}

func knownType(t string) bool {
	for _, k := range Types {
		if k == t {
			return true
		}
	}
	return false
}

// open проверяет конверт ожидаемого типа и разбирает payload в v.
func open(s *Signed, t string, v interface{ validate() error }) error {
	if s.T != t {
		return fail(ErrWrongType, "ожидался %q, получен %q", t, s.T)
	}
	if err := s.Verify(); err != nil {
		return err
	}
	if err := codec.Unmarshal(s.P, v); err != nil {
		return fail(ErrBadPayload, "%v", err)
	}
	return v.validate()
}
