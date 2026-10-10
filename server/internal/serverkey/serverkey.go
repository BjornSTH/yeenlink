// Package serverkey — ключ сервера Ed25519: создаётся при первом запуске,
// хранится в PKCS#8 PEM с правами 0600.
package serverkey

import (
	"crypto/ed25519"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"io/fs"
	"os"
)

// LoadOrCreate читает ключ из path или создаёт новый. created — ключ новый.
func LoadOrCreate(path string) (key ed25519.PrivateKey, created bool, err error) {
	b, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		_, k, err := ed25519.GenerateKey(rand.Reader)
		if err != nil {
			return nil, false, err
		}
		der, err := x509.MarshalPKCS8PrivateKey(k)
		if err != nil {
			return nil, false, err
		}
		data := pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der})
		// O_EXCL: не перезаписать ключ, если его создали параллельно.
		f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
		if err != nil {
			return nil, false, err
		}
		if _, err := f.Write(data); err != nil {
			_ = f.Close()
			return nil, false, err
		}
		return k, true, f.Close()
	}
	if err != nil {
		return nil, false, err
	}
	if st, err := os.Stat(path); err == nil && st.Mode().Perm()&0o077 != 0 {
		return nil, false, fmt.Errorf("serverkey: %s доступен другим пользователям (%v) — нужно 0600", path, st.Mode().Perm())
	}
	blk, _ := pem.Decode(b)
	if blk == nil || blk.Type != "PRIVATE KEY" {
		return nil, false, fmt.Errorf("serverkey: %s не PEM PRIVATE KEY", path)
	}
	k, err := x509.ParsePKCS8PrivateKey(blk.Bytes)
	if err != nil {
		return nil, false, err
	}
	ek, ok := k.(ed25519.PrivateKey)
	if !ok {
		return nil, false, fmt.Errorf("serverkey: %s — не Ed25519", path)
	}
	return ek, false, nil
}
