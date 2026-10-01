package codec_test

import (
	"bytes"
	"math"
	"testing"

	"yeenlink/server/pkg/codec"
)

type challenge struct {
	Nonce     []byte `cbor:"nonce"`
	ServerPub []byte `cbor:"server_pub"`
	TS        uint64 `cbor:"ts"`
}

func TestFrameRoundTrip(t *testing.T) {
	in := challenge{Nonce: bytes.Repeat([]byte{1}, 32), ServerPub: bytes.Repeat([]byte{2}, 32), TS: 1790000000000}
	f, err := codec.NewFrame("challenge", nil, in)
	if err != nil {
		t.Fatal(err)
	}
	for _, w := range []codec.Wire{codec.WireCBOR, codec.WireJSON} {
		t.Run(w.String(), func(t *testing.T) {
			b, err := w.EncodeFrame(f)
			if err != nil {
				t.Fatal(err)
			}
			got, err := w.DecodeFrame(b)
			if err != nil {
				t.Fatal(err)
			}
			var out challenge
			if err := got.DecodeD(&out); err != nil {
				t.Fatal(err)
			}
			if got.Op != "challenge" || got.ID != nil || !bytes.Equal(out.Nonce, in.Nonce) || out.TS != in.TS {
				t.Fatalf("кадр изменился: %+v %+v", got, out)
			}
		})
	}
}

func TestSignedPayloadKeptAsIs(t *testing.T) {
	// Неканонический payload внутри d не пересобирается: подпись считается
	// от байтов, а не от значения.
	payload := []byte{0xa2, 0x61, 0x62, 0x01, 0x61, 0x61, 0x02} // {"b":1,"a":2} — ключи не по порядку
	f, err := codec.NewFrame("profile.push", codec.ID(5), map[string]any{"p": payload})
	if err != nil {
		t.Fatal(err)
	}
	b, err := f.Encode()
	if err != nil {
		t.Fatal(err)
	}
	got, err := codec.DecodeFrame(b)
	if err != nil {
		t.Fatal(err)
	}
	var d struct {
		P []byte `cbor:"p"`
	}
	if err := got.DecodeD(&d); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(d.P, payload) {
		t.Fatalf("payload изменился: %x", d.P)
	}
}

func TestFrameChecks(t *testing.T) {
	cases := map[string]*codec.Frame{
		"нет op":     {D: []byte{0}},
		"d и e":      {Op: "x", ID: codec.ID(1), D: []byte{0}, E: &codec.FrameError{Code: "c"}},
		"e без code": {Op: "x", ID: codec.ID(1), E: &codec.FrameError{}},
		"id > int64": {Op: "x", ID: codec.ID(math.MaxUint64)},
	}
	for name, f := range cases {
		if _, err := f.Encode(); err == nil {
			t.Errorf("%s: кадр закодирован, а не должен", name)
		}
	}
}

func TestJSONEdgeCases(t *testing.T) {
	nan, _ := codec.Marshal(math.NaN())
	if _, err := codec.ToJSON(nan, codec.JSONOptions{}); codec.KindOf(err) != codec.ErrJSON {
		t.Errorf("NaN в JSON: %v", err)
	}
	clash, _ := codec.Marshal(map[string]any{"$bytes": "x"})
	if _, err := codec.ToJSON(clash, codec.JSONOptions{}); codec.KindOf(err) != codec.ErrJSON {
		t.Errorf("словарь {$bytes} в JSON: %v", err)
	}
	for in, kind := range map[string]codec.ErrKind{
		`{"a":1,"a":2}`:                       codec.ErrDupKey,
		`18446744073709551615`:                codec.ErrIntRange,
		`{"$bytes":"***"}`:                    codec.ErrJSON,
		`{"op":"x"} 1`:                        codec.ErrTrailing,
		`[[[[[[[[[[[[[[[[[0]]]]]]]]]]]]]]]]]`: codec.ErrDepth,
	} {
		if _, err := codec.FromJSON([]byte(in)); codec.KindOf(err) != kind {
			t.Errorf("%s: ожидалась %s, получено %v", in, kind, err)
		}
	}
	// Целое и float различаются и после JSON.
	b, err := codec.FromJSON([]byte(`[1, 1.0]`))
	if err != nil {
		t.Fatal(err)
	}
	if want := []byte{0x82, 0x01, 0xfb, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0}; !bytes.Equal(b, want) {
		t.Errorf("1 и 1.0: %x", b)
	}
}

func TestParseWire(t *testing.T) {
	if w, err := codec.ParseWire("json"); err != nil || w != codec.WireJSON {
		t.Fatal(w, err)
	}
	if _, err := codec.ParseWire("xml"); err == nil {
		t.Fatal("xml принят")
	}
}
