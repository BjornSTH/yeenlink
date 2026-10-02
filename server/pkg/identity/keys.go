package identity

import (
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/hex"
	"strings"
)

// Путь вывода главного ключа: m/22860'/0'/i' (spec/identity.md).
const (
	Purpose        uint32 = 22860 // 0x594C, ASCII «YL»
	BranchIdentity uint32 = 0
)

// MasterPath — путь главного ключа поколения gen (0 — текущий, 1 — следующий).
func MasterPath(gen uint32) []uint32 {
	return []uint32{Purpose + Hardened, BranchIdentity + Hardened, gen + Hardened}
}

// Identity — главный ключ и всё, что выводится из фразы.
type Identity struct {
	Entropy     []byte
	Mnemonic    string
	Master      ed25519.PrivateKey
	NextPub     ed25519.PublicKey
	NextKeyHash [32]byte
}

// MasterPub — открытый главный ключ.
func (id *Identity) MasterPub() ed25519.PublicKey {
	return id.Master.Public().(ed25519.PublicKey)
}

// FromMnemonic проверяет фразу и выводит ключи. Ввод нормализуется.
func FromMnemonic(mnemonic string) (*Identity, error) {
	m := NormalizeMnemonic(mnemonic)
	entropy, err := MnemonicToEntropy(m)
	if err != nil {
		return nil, err
	}
	return derive(entropy, m)
}

// FromEntropy выводит ключи из энтропии фразы (так она хранится под PIN).
func FromEntropy(entropy []byte) (*Identity, error) {
	m, err := EntropyToMnemonic(entropy)
	if err != nil {
		return nil, err
	}
	return derive(entropy, m)
}

func derive(entropy []byte, mnemonic string) (*Identity, error) {
	seed := MnemonicToSeed(mnemonic, "")
	cur, err := DerivePath(seed, MasterPath(0))
	if err != nil {
		return nil, err
	}
	next, err := DerivePath(seed, MasterPath(1))
	if err != nil {
		return nil, err
	}
	nextPub := ed25519.NewKeyFromSeed(next.Key[:]).Public().(ed25519.PublicKey)
	return &Identity{
		Entropy:     append([]byte{}, entropy...),
		Mnemonic:    mnemonic,
		Master:      ed25519.NewKeyFromSeed(cur.Key[:]),
		NextPub:     nextPub,
		NextKeyHash: sha256.Sum256(nextPub),
	}, nil
}

// Fingerprint — отпечаток для людей: первые 8 байт SHA-256 открытого ключа,
// четыре группы по 4 hex-символа через «·»: A0D2·5F11·8C3E·07B9.
func Fingerprint(pub []byte) string {
	sum := sha256.Sum256(pub)
	h := strings.ToUpper(hex.EncodeToString(sum[:8]))
	return h[0:4] + "·" + h[4:8] + "·" + h[8:12] + "·" + h[12:16]
}

// ShortFingerprint — первые две группы, для карточек: A0D2·5F11.
func ShortFingerprint(pub []byte) string {
	return Fingerprint(pub)[:len("A0D2·5F11")]
}
