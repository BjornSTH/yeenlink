// Package admintoken — ключ администратора ylat_<43 символа base62>: создаётся
// при первом запуске и командой ylsrv admin-token, хранится файлом 0600, в
// базе — только SHA-256 (docs/spec.md, «Владелец и ключ администратора»).
package admintoken

import (
	"crypto/rand"
	"crypto/sha256"
	"errors"
	"math/big"
	"os"
	"strings"
)

const (
	// Prefix — начало ключа.
	Prefix = "ylat_"
	// Len — длина base62 от 32 байт: ⌈256 / log2 62⌉ = 43.
	Len      = 43
	alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
)

// New создаёт ключ из 32 случайных байт.
func New() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return Encode(b), nil
}

// Encode — ylat_ + base62 (старшие разряды слева, дополнение нулями до 43).
func Encode(b []byte) string {
	n := new(big.Int).SetBytes(b)
	base := big.NewInt(62)
	out := make([]byte, Len)
	for i := Len - 1; i >= 0; i-- {
		var r big.Int
		n.DivMod(n, base, &r)
		out[i] = alphabet[r.Int64()]
	}
	return Prefix + string(out)
}

// Valid — похоже ли на ключ (формат, без проверки по базе).
func Valid(token string) bool {
	rest, ok := strings.CutPrefix(token, Prefix)
	if !ok || len(rest) != Len {
		return false
	}
	for i := 0; i < len(rest); i++ {
		if !strings.ContainsRune(alphabet, rune(rest[i])) {
			return false
		}
	}
	return true
}

// Hash — то, что хранится в базе.
func Hash(token string) []byte {
	h := sha256.Sum256([]byte(strings.TrimSpace(token)))
	return h[:]
}

// WriteFile кладёт ключ в файл с правами 0600, заменяя прежний.
func WriteFile(path, token string) error {
	tmp := path + ".tmp"
	_ = os.Remove(tmp)
	if err := os.WriteFile(tmp, []byte(token+"\n"), 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// RemoveFile удаляет файл ключа после использования; отсутствие — не ошибка.
func RemoveFile(path string) error {
	if err := os.Remove(path); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}
