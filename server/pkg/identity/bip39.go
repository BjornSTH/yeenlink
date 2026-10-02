// Package identity — ключи и подписанные форматы личности YeenLink
// (spec/identity.md): фраза BIP39, вывод ключей SLIP-0010, конверт Signed,
// профиль, сертификат устройства, отзыв, список устройств, отпечатки.
// Та же логика на Dart — client/lib/core/identity; общие векторы —
// testdata/vectors/identity.
package identity

import (
	"crypto/pbkdf2"
	"crypto/sha256"
	"crypto/sha512"
	_ "embed"
	"errors"
	"fmt"
	"strings"
)

//go:embed english.txt
var englishList string

// Wordlist — английский список BIP39 (2048 слов). SHA-256 файла проверяется
// тестом против официального.
var Wordlist = strings.Fields(englishList)

var wordIndex = func() map[string]int {
	m := make(map[string]int, len(Wordlist))
	for i, w := range Wordlist {
		m[w] = i
	}
	return m
}()

// Ошибки разбора фразы. Тексты для человека — в клиенте.
var (
	ErrWordCount = errors.New("identity: во фразе должно быть 12, 15, 18, 21 или 24 слова")
	ErrChecksum  = errors.New("identity: контрольная сумма фразы не сходится")
)

// UnknownWordError — слово не из списка BIP39.
type UnknownWordError struct {
	Index int // с нуля
	Word  string
}

func (e *UnknownWordError) Error() string {
	return fmt.Sprintf("identity: слово %d «%s» не из списка BIP39", e.Index+1, e.Word)
}

// NormalizeMnemonic приводит ввод к виду BIP39: нижний регистр, слова через
// один пробел. Слова списка — ASCII, поэтому NFKD из BIP39 здесь ничего не
// меняет, а любой не-ASCII символ даст UnknownWordError.
func NormalizeMnemonic(s string) string {
	return strings.Join(strings.Fields(strings.ToLower(s)), " ")
}

// EntropyToMnemonic кодирует энтропию (16–32 байта, кратно 4) во фразу.
func EntropyToMnemonic(entropy []byte) (string, error) {
	n := len(entropy)
	if n < 16 || n > 32 || n%4 != 0 {
		return "", fmt.Errorf("identity: энтропия %d байт, нужно 16–32 кратно 4", n)
	}
	sum := sha256.Sum256(entropy)
	csBits := n * 8 / 32
	bits := append(append([]byte{}, entropy...), sum[0])
	words := make([]string, (n*8+csBits)/11)
	for i := range words {
		idx := 0
		for b := range 11 {
			pos := i*11 + b
			idx = idx<<1 | int(bits[pos/8]>>(7-pos%8)&1)
		}
		words[i] = Wordlist[idx]
	}
	return strings.Join(words, " "), nil
}

// MnemonicToEntropy проверяет фразу (слова и контрольную сумму) и
// возвращает энтропию. Фраза должна быть нормализована.
func MnemonicToEntropy(mnemonic string) ([]byte, error) {
	words := strings.Split(mnemonic, " ")
	switch len(words) {
	case 12, 15, 18, 21, 24:
	default:
		return nil, ErrWordCount
	}
	total := len(words) * 11
	csBits := total / 33
	entBytes := (total - csBits) / 8
	bits := make([]byte, (total+7)/8)
	for i, w := range words {
		idx, ok := wordIndex[w]
		if !ok {
			return nil, &UnknownWordError{Index: i, Word: w}
		}
		for b := range 11 {
			if idx>>(10-b)&1 == 1 {
				pos := i*11 + b
				bits[pos/8] |= 1 << (7 - pos%8)
			}
		}
	}
	entropy := bits[:entBytes]
	sum := sha256.Sum256(entropy)
	if bits[entBytes]>>(8-csBits) != sum[0]>>(8-csBits) {
		return nil, ErrChecksum
	}
	return append([]byte{}, entropy...), nil
}

// MnemonicToSeed — seed BIP39: PBKDF2-HMAC-SHA512(фраза, "mnemonic"+пароль,
// 2048), 64 байта. YeenLink использует пустой пароль; непустой нужен только
// для официальных векторов (ASCII, поэтому без NFKD).
func MnemonicToSeed(mnemonic, passphrase string) []byte {
	seed, err := pbkdf2.Key(sha512.New, mnemonic, []byte("mnemonic"+passphrase), 2048, 64)
	if err != nil {
		panic(err) // возможно только при недопустимых параметрах, а они постоянные
	}
	return seed
}
