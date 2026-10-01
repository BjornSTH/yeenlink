package main

import (
	"bytes"
	"encoding/base64"
	"encoding/hex"
	"strings"
	"testing"

	"yeenlink/server/pkg/codec"
)

func frameBytes(t *testing.T) []byte {
	t.Helper()
	f, err := codec.NewFrame("challenge", nil, map[string]any{"nonce": []byte{0xde, 0xad}, "ts": 7})
	if err != nil {
		t.Fatal(err)
	}
	b, err := f.Encode()
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestRun(t *testing.T) {
	b := frameBytes(t)
	const want = `{"d":{"ts":7,"nonce":{"$bytes":"3q0"}},"op":"challenge"}`
	cases := map[string]struct {
		in   string
		data []byte
		n    int
	}{
		"raw-последовательность": {"auto", append(append([]byte{}, b...), b...), 2},
		"hex с префиксом лога":   {"auto", []byte("2026-10-02 05:40 ws recv frame=" + hex.EncodeToString(b) + "\n"), 1},
		"base64url":              {"base64", []byte(base64.RawURLEncoding.EncodeToString(b) + "\n\n"), 1},
		"hex явно":               {"hex", []byte(hex.EncodeToString(b)), 1},
	}
	for name, c := range cases {
		t.Run(name, func(t *testing.T) {
			var out, errOut bytes.Buffer
			if err := run(c.data, options{in: c.in, compact: true}, &out, &errOut); err != nil {
				t.Fatalf("%v; stderr: %s", err, errOut.String())
			}
			lines := strings.Split(strings.TrimSpace(out.String()), "\n")
			if len(lines) != c.n {
				t.Fatalf("кадров %d, ожидалось %d: %s", len(lines), c.n, out.String())
			}
			for _, l := range lines {
				if l != want {
					t.Fatalf("got  %s\nwant %s", l, want)
				}
			}
		})
	}
}

func TestRunBytesHex(t *testing.T) {
	var out, errOut bytes.Buffer
	if err := run(frameBytes(t), options{in: "raw", compact: true, hex: true}, &out, &errOut); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out.String(), `{"$hex":"dead"}`) {
		t.Fatalf("нет hex: %s", out.String())
	}
}

func TestRunGarbage(t *testing.T) {
	var out, errOut bytes.Buffer
	if err := run([]byte("просто строка лога\n"), options{in: "auto"}, &out, &errOut); err == nil {
		t.Fatal("мусор принят за кадр")
	}
}
