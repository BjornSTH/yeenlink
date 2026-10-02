package identity

import (
	"crypto/hmac"
	"crypto/sha512"
	"encoding/binary"
	"errors"
	"fmt"
	"strconv"
	"strings"
)

// Hardened — смещение hardened-индекса. Для Ed25519 SLIP-0010 допускает
// только такие.
const Hardened uint32 = 1 << 31

// Node — узел SLIP-0010 для ed25519: закрытый ключ (seed Ed25519) и chain code.
type Node struct {
	Key       [32]byte
	ChainCode [32]byte
}

// MasterNode — корень SLIP-0010: HMAC-SHA512("ed25519 seed", seed).
func MasterNode(seed []byte) Node {
	return split(hmacSHA512([]byte("ed25519 seed"), seed))
}

// Child выводит hardened-потомка с индексом index (уже со смещением Hardened).
func (n Node) Child(index uint32) (Node, error) {
	if index < Hardened {
		return Node{}, fmt.Errorf("identity: индекс %d не hardened, для ed25519 так нельзя", index)
	}
	data := make([]byte, 0, 37)
	data = append(data, 0)
	data = append(data, n.Key[:]...)
	data = binary.BigEndian.AppendUint32(data, index)
	return split(hmacSHA512(n.ChainCode[:], data)), nil
}

// DerivePath выводит узел по пути из seed.
func DerivePath(seed []byte, path []uint32) (Node, error) {
	n := MasterNode(seed)
	for _, idx := range path {
		var err error
		if n, err = n.Child(idx); err != nil {
			return Node{}, err
		}
	}
	return n, nil
}

// ParsePath разбирает путь вида m/0'/1'.
func ParsePath(s string) ([]uint32, error) {
	parts := strings.Split(s, "/")
	if parts[0] != "m" {
		return nil, errors.New("identity: путь должен начинаться с m")
	}
	path := make([]uint32, 0, len(parts)-1)
	for _, p := range parts[1:] {
		hard := strings.HasSuffix(p, "'")
		v, err := strconv.ParseUint(strings.TrimSuffix(p, "'"), 10, 31)
		if err != nil || !hard {
			return nil, fmt.Errorf("identity: неверный элемент пути %q", p)
		}
		path = append(path, uint32(v)+Hardened)
	}
	return path, nil
}

func hmacSHA512(key, data []byte) []byte {
	m := hmac.New(sha512.New, key)
	m.Write(data)
	return m.Sum(nil)
}

func split(i []byte) Node {
	var n Node
	copy(n.Key[:], i[:32])
	copy(n.ChainCode[:], i[32:])
	return n
}
