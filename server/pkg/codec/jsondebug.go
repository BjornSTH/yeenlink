package codec

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"math"
	"slices"
	"strconv"
	"strings"
)

// Отладочный JSON — представление модели данных CBOR, а не отдельная
// сериализация структур (spec/json-debug.md). Внутри сервер всегда работает
// с CBOR; JSON появляется только на проводе в режиме --codec=json и в
// yl-decode. Правила:
//
//   - байтовая строка — {"$bytes": "<base64url без =>"};
//   - число с плавающей точкой всегда с точкой или экспонентой, целое — без;
//   - ключи словаря — только текст, выводятся в порядке CBOR (§4.2.1).

const bytesKey = "$bytes"

// JSONOptions — настройки вывода ToJSON.
type JSONOptions struct {
	Indent   string // пусто — одной строкой
	BytesHex bool   // байты как {"$hex": …} — только для чтения человеком, FromJSON это не примет
}

// ToJSON переводит одно значение CBOR в отладочный JSON.
func ToJSON(data []byte, opt JSONOptions) ([]byte, error) {
	v, err := Decode(data)
	if err != nil {
		return nil, err
	}
	var b bytes.Buffer
	if err := writeJSON(&b, v, opt); err != nil {
		return nil, err
	}
	if opt.Indent == "" {
		return b.Bytes(), nil
	}
	var out bytes.Buffer
	if err := json.Indent(&out, b.Bytes(), "", opt.Indent); err != nil {
		return nil, err
	}
	return out.Bytes(), nil
}

func writeJSON(b *bytes.Buffer, v any, opt JSONOptions) error {
	switch x := v.(type) {
	case nil:
		b.WriteString("null")
	case bool:
		b.WriteString(strconv.FormatBool(x))
	case int64:
		b.WriteString(strconv.FormatInt(x, 10))
	case float64:
		if math.IsNaN(x) || math.IsInf(x, 0) {
			return errf(ErrJSON, "%v не представимо в JSON", x)
		}
		s := strconv.FormatFloat(x, 'g', -1, 64)
		if !strings.ContainsAny(s, ".eE") {
			s += ".0"
		}
		b.WriteString(s)
	case string:
		writeString(b, x)
	case []byte:
		if opt.BytesHex {
			b.WriteString(`{"$hex":"`)
			fmt.Fprintf(b, "%x", x)
			b.WriteString(`"}`)
		} else {
			b.WriteString(`{"` + bytesKey + `":"`)
			b.WriteString(base64.RawURLEncoding.EncodeToString(x))
			b.WriteString(`"}`)
		}
	case []any:
		b.WriteByte('[')
		for i, e := range x {
			if i > 0 {
				b.WriteByte(',')
			}
			if err := writeJSON(b, e, opt); err != nil {
				return err
			}
		}
		b.WriteByte(']')
	case map[string]any:
		if _, ok := x[bytesKey]; ok && len(x) == 1 {
			return errf(ErrJSON, "словарь с единственным ключом %q неотличим от байтов", bytesKey)
		}
		b.WriteByte('{')
		for i, k := range SortedKeys(x) {
			if i > 0 {
				b.WriteByte(',')
			}
			writeString(b, k)
			b.WriteByte(':')
			if err := writeJSON(b, x[k], opt); err != nil {
				return err
			}
		}
		b.WriteByte('}')
	default:
		return errf(ErrJSON, "неожиданный тип %T", v)
	}
	return nil
}

func writeString(b *bytes.Buffer, s string) {
	enc := json.NewEncoder(b)
	enc.SetEscapeHTML(false)
	_ = enc.Encode(s)       // строка уже проверена на UTF-8 при разборе CBOR
	b.Truncate(b.Len() - 1) // Encode добавляет перевод строки
}

// SortedKeys возвращает ключи в порядке детерминированного CBOR: сначала
// короче, при равной длине — побайтово.
func SortedKeys(m map[string]any) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	slices.SortFunc(keys, func(a, b string) int {
		if len(a) != len(b) {
			return len(a) - len(b)
		}
		return strings.Compare(a, b)
	})
	return keys
}

// FromJSON переводит отладочный JSON в детерминированный CBOR.
func FromJSON(data []byte) ([]byte, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.UseNumber()
	v, err := readJSON(dec, 0)
	if err != nil {
		return nil, err
	}
	if _, err := dec.Token(); !errors.Is(err, io.EOF) {
		return nil, errf(ErrTrailing, "лишние данные после JSON")
	}
	return Marshal(v)
}

func readJSON(dec *json.Decoder, depth int) (any, error) {
	tok, err := dec.Token()
	if err != nil {
		return nil, errf(ErrJSON, "%v", err)
	}
	switch t := tok.(type) {
	case nil, bool, string:
		return t, nil
	case json.Number:
		return parseNumber(string(t))
	case json.Delim:
		if depth >= MaxDepth {
			return nil, errf(ErrDepth, "глубже %d", MaxDepth)
		}
		if t == '[' {
			arr := []any{}
			for dec.More() {
				if len(arr) == MaxItems {
					return nil, errf(ErrSize, "массив больше %d", MaxItems)
				}
				e, err := readJSON(dec, depth+1)
				if err != nil {
					return nil, err
				}
				arr = append(arr, e)
			}
			_, _ = dec.Token()
			return arr, nil
		}
		m := map[string]any{}
		for dec.More() {
			kt, err := dec.Token()
			if err != nil {
				return nil, errf(ErrJSON, "%v", err)
			}
			k := kt.(string)
			if _, dup := m[k]; dup {
				return nil, errf(ErrDupKey, "ключ %q повторяется", k)
			}
			if len(m) == MaxItems {
				return nil, errf(ErrSize, "словарь больше %d", MaxItems)
			}
			e, err := readJSON(dec, depth+1)
			if err != nil {
				return nil, err
			}
			m[k] = e
		}
		_, _ = dec.Token()
		if s, ok := m[bytesKey]; ok && len(m) == 1 {
			str, ok := s.(string)
			if !ok {
				return nil, errf(ErrJSON, "%s должен быть строкой", bytesKey)
			}
			raw, err := base64.RawURLEncoding.DecodeString(str)
			if err != nil {
				return nil, errf(ErrJSON, "%s: %v", bytesKey, err)
			}
			return raw, nil
		}
		return m, nil
	}
	return nil, errf(ErrJSON, "неожиданный токен %v", tok)
}

func parseNumber(s string) (any, error) {
	if strings.ContainsAny(s, ".eE") {
		f, err := strconv.ParseFloat(s, 64)
		if err != nil {
			return nil, errf(ErrJSON, "число %s: %v", s, err)
		}
		return f, nil
	}
	i, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return nil, errf(ErrIntRange, "целое %s вне int64", s)
	}
	return i, nil
}
