// Команда vectorgen пишет общие тестовые векторы в testdata/vectors:
//
//   - codec/ — кадры: для каждого вектора <имя>.cbor и <имя>.json;
//   - identity/ — фраза → ключи → подписанные конверты (keys.json, envelopes.json).
//
// Векторы проверяются тестами и в Go, и в Dart. Официальные векторы BIP39 и
// SLIP-0010 (testdata/vectors/bip39, slip10) скопированы из источников и здесь
// не генерируются. Запуск: make vectors.
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	"yeenlink/server/pkg/codec"
)

type vector struct {
	name, desc string
	value      *codec.Frame // корректный канонический кадр
	raw        []byte       // байты вручную: неканонический или недопустимый кадр
	errKind    codec.ErrKind
}

type manifest struct {
	Description string          `json:"description"`
	Valid       bool            `json:"valid"`
	Canonical   bool            `json:"canonical"`
	Error       string          `json:"error,omitempty"`
	Frame       json.RawMessage `json:"frame,omitempty"`
}

func main() {
	root := flag.String("root", "../testdata/vectors", "папка с векторами")
	flag.Parse()

	codecDir := filepath.Join(*root, "codec")
	if err := resetDir(codecDir); err != nil {
		log.Fatal(err)
	}
	for _, v := range vectors() {
		if err := write(codecDir, v); err != nil {
			log.Fatalf("%s: %v", v.name, err)
		}
	}
	identityDir := filepath.Join(*root, "identity")
	if err := resetDir(identityDir); err != nil {
		log.Fatal(err)
	}
	if err := writeIdentity(identityDir); err != nil {
		log.Fatalf("identity: %v", err)
	}
}

func resetDir(dir string) error {
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return err
	}
	old, _ := filepath.Glob(filepath.Join(dir, "*"))
	for _, p := range old {
		if err := os.Remove(p); err != nil {
			return err
		}
	}
	return nil
}

func write(dir string, v vector) error {
	m := manifest{Description: v.desc}
	data := v.raw
	if v.value != nil {
		b, err := v.value.Encode()
		if err != nil {
			return err
		}
		data = b
	}
	_, err := codec.DecodeFrame(data)
	switch {
	case v.errKind != "":
		if codec.KindOf(err) != v.errKind {
			return fmt.Errorf("ожидалась ошибка %s, получено %w", v.errKind, err)
		}
		m.Error = string(v.errKind)
	case err != nil:
		return err
	default:
		m.Valid = true
		if m.Frame, err = codec.ToJSON(data, codec.JSONOptions{}); err != nil {
			return err
		}
		// Канонический — байты совпадают с полным перекодированием значения.
		canon, err := codec.FromJSON(m.Frame)
		if err != nil {
			return err
		}
		m.Canonical = bytes.Equal(canon, data)
		if v.value != nil && !m.Canonical {
			return fmt.Errorf("кадр из значения оказался неканоническим")
		}
	}
	js, err := json.MarshalIndent(m, "", "  ")
	if err != nil {
		return err
	}
	if err := os.WriteFile(filepath.Join(dir, v.name+".cbor"), data, 0o644); err != nil {
		return err
	}
	return os.WriteFile(filepath.Join(dir, v.name+".json"), append(js, '\n'), 0o644)
}

// fixed — детерминированные «случайные» байты для векторов.
func fixed(label string, n int) []byte {
	var out []byte
	for i := 0; len(out) < n; i++ {
		h := sha256.Sum256(fmt.Appendf(nil, "yl-vector/%s/%d", label, i))
		out = append(out, h[:]...)
	}
	return out[:n]
}

func frame(op string, id *uint64, d any) *codec.Frame {
	f, err := codec.NewFrame(op, id, d)
	if err != nil {
		panic(err)
	}
	return f
}

// h собирает байты из hex с пробелами и комментариями после «;».
func h(s string) []byte {
	var clean strings.Builder
	for line := range strings.SplitSeq(s, "\n") {
		if i := strings.IndexByte(line, ';'); i >= 0 {
			line = line[:i]
		}
		clean.WriteString(strings.Join(strings.Fields(line), ""))
	}
	b, err := hex.DecodeString(clean.String())
	if err != nil {
		panic(err)
	}
	return b
}

func cat(parts ...[]byte) []byte { return bytes.Join(parts, nil) }

// nested возвращает CBOR из n вложенных массивов с нулём внутри.
func nested(n int) []byte {
	return cat(bytes.Repeat([]byte{0x81}, n), []byte{0x00})
}

func vectors() []vector {
	profile, err := codec.Marshal(map[string]any{"v": 1, "seq": 3, "name": "Пятнистый"})
	if err != nil {
		panic(err)
	}
	// 16385 нулей — на один больше codec.MaxItems.
	tooMany := cat(h("a2 626f70 6474657374 6164"), h("99 4001"), bytes.Repeat([]byte{0}, codec.MaxItems+1))

	// Глубина — число вложенных контейнеров, сам кадр — первый. В d кладём
	// массивы так, чтобы общая глубина была ровно MaxDepth и на один больше.
	frameWithD := func(d []byte) []byte { return cat(h("a2 6164"), d, h("626f70 6474657374")) }

	return []vector{
		{name: "req_msg_send", desc: "Запрос клиента с id и текстом на кириллице и эмодзи",
			value: frame("msg.send", codec.ID(1), map[string]any{
				"channel": "общий", "client_id": "01J9Z3K8Q4V5M2N7P6R1S0T2W3", "text": "Пятница в силе? 🎲"})},
		{name: "resp_ok", desc: "Ответ сервера с тем же id и полем d",
			value: frame("msg.send", codec.ID(1), map[string]any{"id": "01J9Z3K8Q4V5M2N7P6R1S0T2W4", "ts": int64(1790000000123)})},
		{name: "resp_err", desc: "Ответ сервера с ошибкой e вместо d",
			value: &codec.Frame{Op: "auth", ID: codec.ID(2), E: &codec.FrameError{Code: "bad_sig", Msg: "Подпись не сошлась"}}},
		{name: "event_challenge", desc: "Событие сервера без id с байтовыми полями",
			value: frame("challenge", nil, map[string]any{
				"nonce": fixed("nonce", 32), "server_pub": fixed("server", 32), "ts": int64(1790000000000)})},
		{name: "event_signed", desc: "Конверт Signed внутри d: p — байты CBOR, хранятся как есть (s — заглушка, не подпись)",
			value: frame("member.update", nil, map[string]any{"profile": map[string]any{
				"t": "profile", "p": profile, "k": fixed("master", 32), "s": fixed("sig", 64)}})},
		{name: "ints", desc: "Целые на границах кратчайших форм и int64",
			value: frame("test.ints", nil, map[string]any{"values": []any{
				0, 1, 23, 24, 255, 256, 65535, 65536, 4294967295, int64(4294967296), int64(9223372036854775807),
				-1, -24, -25, -256, -257, int64(-9223372036854775808)}})},
		{name: "floats", desc: "Числа с плавающей точкой всегда кодируются в 64 бита",
			value: frame("test.floats", nil, map[string]any{"values": []any{1.0, 1.5, -2.5, 0.1, 1e300}})},
		{name: "empty_and_null", desc: "null, логические, пустые коллекции, байты и строка",
			value: frame("test.empty", nil, map[string]any{
				"null": nil, "yes": true, "no": false, "map": map[string]any{}, "list": []any{}, "bytes": []byte{}, "text": ""})},
		{name: "key_order", desc: "Порядок ключей §4.2.1: сначала короче, затем побайтово (кириллица — 2 байта на букву)",
			value: frame("test.keys", nil, map[string]any{"b": 1, "a": 2, "aa": 3, "z": 4, "ключ": 5, "Z": 6})},
		{name: "depth_max", desc: "Вложенность ровно MaxDepth — допустима",
			raw: frameWithD(nested(codec.MaxDepth - 1))},
		{name: "d_null", desc: "Поле d со значением null отличается от отсутствующего d",
			value: &codec.Frame{Op: "test.null", D: []byte{0xf6}}},

		{name: "noncanon_key_order", desc: "Ключи не по порядку — кадр принимается, но перекодируется иначе",
			raw: h("a3 626f70 6474657374 626964 01 6164 00")},
		{name: "noncanon_int", desc: "Целое не в кратчайшей форме (1 как 0x18 0x01) — принимается",
			raw: h("a2 626964 1801 626f70 6474657374")},
		{name: "noncanon_float32", desc: "float32 на входе допустим, на выходе станет float64",
			raw: frameWithD(h("fa 3fc00000"))},

		{name: "bad_dup_key", desc: "Повтор ключа op", errKind: codec.ErrDupKey,
			raw: h("a2 626f70 6161 626f70 6162")},
		{name: "bad_indefinite", desc: "Словарь с длиной без счётчика", errKind: codec.ErrIndefinite,
			raw: h("bf 626f70 6474657374 ff")},
		{name: "bad_tag", desc: "Тег 1 (время) внутри d", errKind: codec.ErrTag,
			raw: frameWithD(h("c1 1a 6a9d1e00"))},
		{name: "bad_depth", desc: "Вложенность MaxDepth + 1", errKind: codec.ErrDepth,
			raw: frameWithD(nested(codec.MaxDepth))},
		{name: "bad_size", desc: "Массив из MaxItems + 1 элементов", errKind: codec.ErrSize,
			raw: tooMany},
		{name: "bad_utf8", desc: "Текст не в UTF-8", errKind: codec.ErrUTF8,
			raw: h("a1 626f70 62 c328")},
		{name: "bad_undefined", desc: "undefined в d", errKind: codec.ErrSimple,
			raw: frameWithD(h("f7"))},
		{name: "bad_simple", desc: "Незарегистрированное простое значение 16", errKind: codec.ErrSimple,
			raw: frameWithD(h("f0"))},
		{name: "bad_uint_range", desc: "Целое 2^64 − 1 не помещается в int64", errKind: codec.ErrIntRange,
			raw: frameWithD(h("1b ffffffffffffffff"))},
		{name: "bad_nint_range", desc: "Целое −2^64 не помещается в int64", errKind: codec.ErrIntRange,
			raw: frameWithD(h("3b ffffffffffffffff"))},
		{name: "bad_trailing", desc: "Лишний байт после кадра", errKind: codec.ErrTrailing,
			raw: h("a1 626f70 6474657374 00")},
		{name: "bad_truncated", desc: "Кадр оборван", errKind: codec.ErrMalformed,
			raw: h("a2 626f70 6474657374 6164")},
		{name: "bad_key_type", desc: "Ключ словаря — число", errKind: codec.ErrKeyType,
			raw: h("a2 01 00 626f70 6474657374")},
		{name: "bad_no_op", desc: "В кадре нет op", errKind: codec.ErrFrameShape,
			raw: h("a1 6164 00")},
		{name: "bad_op_type", desc: "op не текст", errKind: codec.ErrFrameShape,
			raw: h("a1 626f70 05")},
		{name: "bad_not_map", desc: "Кадр — массив, а не словарь", errKind: codec.ErrFrameShape,
			raw: h("82 6474657374 00")},
		{name: "bad_d_and_e", desc: "В кадре одновременно d и e", errKind: codec.ErrFrameShape,
			raw: h("a4 6164 00 6165 a2 64636f6465 6178 636d7367 60 626964 01 626f70 6474657374")},
	}
}
