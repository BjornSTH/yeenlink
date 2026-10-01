package codec_test

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yeenlink/server/pkg/codec"
)

const vectorDir = "../../../testdata/vectors/codec"

type manifest struct {
	Valid     bool            `json:"valid"`
	Canonical bool            `json:"canonical"`
	Error     string          `json:"error"`
	Frame     json.RawMessage `json:"frame"`
}

func TestVectors(t *testing.T) {
	files, err := filepath.Glob(filepath.Join(vectorDir, "*.json"))
	if err != nil || len(files) == 0 {
		t.Fatalf("векторы не найдены в %s: %v", vectorDir, err)
	}
	for _, path := range files {
		name := strings.TrimSuffix(filepath.Base(path), ".json")
		t.Run(name, func(t *testing.T) {
			var m manifest
			js, err := os.ReadFile(path)
			if err != nil {
				t.Fatal(err)
			}
			if err := json.Unmarshal(js, &m); err != nil {
				t.Fatal(err)
			}
			data, err := os.ReadFile(strings.TrimSuffix(path, ".json") + ".cbor")
			if err != nil {
				t.Fatal(err)
			}

			f, err := codec.DecodeFrame(data)
			if !m.Valid {
				if got := codec.KindOf(err); got != codec.ErrKind(m.Error) {
					t.Fatalf("ожидалась ошибка %q, получено %q (%v)", m.Error, got, err)
				}
				return
			}
			if err != nil {
				t.Fatalf("кадр не разобран: %v", err)
			}

			// Значение совпадает с ожидаемым: сравниваем через канонический CBOR,
			// чтобы не зависеть от форматирования JSON.
			want, err := codec.FromJSON(m.Frame)
			if err != nil {
				t.Fatalf("ожидаемый JSON: %v", err)
			}
			gotJSON, err := codec.ToJSON(data, codec.JSONOptions{})
			if err != nil {
				t.Fatal(err)
			}
			got, err := codec.FromJSON(gotJSON)
			if err != nil {
				t.Fatal(err)
			}
			if !bytes.Equal(got, want) {
				t.Fatalf("значение не совпало:\n got %s\nwant %s", gotJSON, m.Frame)
			}
			if m.Canonical != bytes.Equal(want, data) {
				t.Fatalf("canonical=%v, а перекодирование даёт другое", m.Canonical)
			}

			// Отладочный JSON на проводе даёт тот же кадр.
			jf, err := codec.WireJSON.DecodeFrame(m.Frame)
			if err != nil {
				t.Fatalf("JSON-кадр: %v", err)
			}
			if jf.Op != f.Op || (jf.ID == nil) != (f.ID == nil) {
				t.Fatalf("JSON-кадр отличается: %+v против %+v", jf, f)
			}
			if m.Canonical {
				enc, err := f.Encode()
				if err != nil {
					t.Fatal(err)
				}
				if !bytes.Equal(enc, data) {
					t.Fatalf("перекодированный кадр отличается:\n got %x\nwant %x", enc, data)
				}
			}
		})
	}
}
