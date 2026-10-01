// Package codec — единственный путь, которым сервер кодирует и разбирает
// CBOR. Профиль кодирования общий с клиентом (client/lib/core/codec) и
// описан в spec/README.md; общие векторы лежат в testdata/vectors/codec.
//
// Кодирование детерминированное: ключи словарей отсортированы по RFC 8949
// §4.2.1, длины заданы явно, целые — в кратчайшей форме, числа с плавающей
// точкой — всегда 64 бита. Разбор строгий: дубликаты ключей, теги, длины
// без счётчика, undefined и целые вне int64 отвергаются, глубина и размеры
// ограничены.
package codec

import (
	"errors"
	"fmt"
	"io"
	"math"
	"math/big"

	"github.com/fxamacker/cbor/v2"
)

// Ограничения разбора. Кадр глубже MaxDepth или с коллекцией больше
// MaxItems не принимается, чтобы один клиент не мог занять память сервера.
const (
	MaxDepth = 16
	MaxItems = 16384
)

// ErrKind — категория ошибки разбора. Те же строки возвращает Dart-кодек,
// и ими же размечены недопустимые векторы.
type ErrKind string

// Категории ошибок разбора.
const (
	ErrMalformed  ErrKind = "malformed"   // обрыв или синтаксическая ошибка
	ErrTrailing   ErrKind = "trailing"    // лишние байты после значения
	ErrDupKey     ErrKind = "dup_key"     // повтор ключа в словаре
	ErrIndefinite ErrKind = "indefinite"  // длина без счётчика
	ErrTag        ErrKind = "tag"         // любой тег CBOR
	ErrDepth      ErrKind = "depth"       // глубже MaxDepth
	ErrSize       ErrKind = "size"        // коллекция больше MaxItems
	ErrUTF8       ErrKind = "utf8"        // текст не в UTF-8
	ErrSimple     ErrKind = "simple"      // undefined и прочие простые значения
	ErrIntRange   ErrKind = "int_range"   // целое вне int64
	ErrKeyType    ErrKind = "key_type"    // ключ словаря не текст
	ErrFrameShape ErrKind = "frame_shape" // значение не похоже на кадр
	ErrJSON       ErrKind = "json"        // отладочный JSON не переводится в CBOR
)

// Error — ошибка кодека с категорией.
type Error struct {
	Kind ErrKind
	Err  error
}

func (e *Error) Error() string { return fmt.Sprintf("codec: %s: %v", e.Kind, e.Err) }
func (e *Error) Unwrap() error { return e.Err }

// KindOf возвращает категорию ошибки кодека или пустую строку.
func KindOf(err error) ErrKind {
	var ce *Error
	if errors.As(err, &ce) {
		return ce.Kind
	}
	return ""
}

func errf(kind ErrKind, format string, args ...any) error {
	return &Error{Kind: kind, Err: fmt.Errorf(format, args...)}
}

var (
	encMode cbor.EncMode
	decMode cbor.DecMode
)

func init() {
	var err error
	encMode, err = cbor.EncOptions{
		Sort:          cbor.SortCoreDeterministic,
		ShortestFloat: cbor.ShortestFloatNone,
		NaNConvert:    cbor.NaNConvertNone,
		InfConvert:    cbor.InfConvertNone,
		IndefLength:   cbor.IndefLengthForbidden,
		TagsMd:        cbor.TagsForbidden,
		Time:          cbor.TimeUnixMicro, // время в протоколе — uint, мс; time.Time не используется
		BigIntConvert: cbor.BigIntConvertReject,
	}.EncMode()
	if err != nil {
		panic(err)
	}
	simple, err := cbor.NewSimpleValueRegistryFromDefaults(cbor.WithRejectedSimpleValue(23)) // undefined
	if err != nil {
		panic(err)
	}
	decMode, err = cbor.DecOptions{
		DupMapKey:        cbor.DupMapKeyEnforcedAPF,
		IndefLength:      cbor.IndefLengthForbidden,
		TagsMd:           cbor.TagsForbidden,
		MaxNestedLevels:  MaxDepth,
		MaxArrayElements: MaxItems,
		MaxMapPairs:      MaxItems,
		IntDec:           cbor.IntDecConvertNone,
		UTF8:             cbor.UTF8RejectInvalid,
		SimpleValues:     simple,
	}.DecMode()
	if err != nil {
		panic(err)
	}
}

// Marshal кодирует значение в детерминированный CBOR.
func Marshal(v any) ([]byte, error) {
	b, err := encMode.Marshal(v)
	if err != nil {
		return nil, &Error{Kind: ErrFrameShape, Err: err}
	}
	return b, nil
}

// Unmarshal разбирает ровно одно значение CBOR в v. Перед разбором в
// типизированную структуру всё значение проверяется целиком (Validate),
// так что неизвестные поля тоже обязаны быть корректными.
func Unmarshal(data []byte, v any) error {
	if _, err := Decode(data); err != nil {
		return err
	}
	if err := decMode.Unmarshal(data, v); err != nil {
		return classify(err)
	}
	return nil
}

// Decode разбирает CBOR в модель данных: nil, bool, int64, float64, string,
// []byte, []any, map[string]any. Целое без знака больше math.MaxInt64 —
// ошибка ErrIntRange: в Dart целые 64-битные со знаком.
func Decode(data []byte) (any, error) {
	var raw any
	if err := decMode.Unmarshal(data, &raw); err != nil {
		return nil, classify(err)
	}
	return normalize(raw)
}

// Validate проверяет, что data — одно допустимое значение CBOR.
func Validate(data []byte) error {
	_, err := Decode(data)
	return err
}

func normalize(v any) (any, error) {
	switch x := v.(type) {
	case nil, bool, string, []byte, float64, int64:
		return x, nil
	case float32:
		return float64(x), nil
	case uint64:
		if x > math.MaxInt64 {
			return nil, errf(ErrIntRange, "%d больше int64", x)
		}
		return int64(x), nil
	case big.Int, *big.Int:
		return nil, errf(ErrIntRange, "целое вне int64")
	case cbor.SimpleValue:
		return nil, errf(ErrSimple, "простое значение %d", x)
	case []any:
		for i := range x {
			n, err := normalize(x[i])
			if err != nil {
				return nil, err
			}
			x[i] = n
		}
		return x, nil
	case map[any]any:
		m := make(map[string]any, len(x))
		for k, val := range x {
			ks, ok := k.(string)
			if !ok {
				return nil, errf(ErrKeyType, "ключ словаря %T, нужен текст", k)
			}
			n, err := normalize(val)
			if err != nil {
				return nil, err
			}
			m[ks] = n
		}
		return m, nil
	default:
		return nil, errf(ErrMalformed, "неожиданный тип %T", v)
	}
}

func classify(err error) error {
	var (
		dup     *cbor.DupMapKeyError
		indef   *cbor.IndefiniteLengthError
		tags    *cbor.TagsMdError
		nested  *cbor.MaxNestedLevelError
		arr     *cbor.MaxArrayElementsError
		mp      *cbor.MaxMapPairsError
		extra   *cbor.ExtraneousDataError
		syn     *cbor.SyntaxError
		sem     *cbor.SemanticError
		unacc   *cbor.UnacceptableDataItemError
		typ     *cbor.UnmarshalTypeError
		keyType *cbor.InvalidMapKeyTypeError
	)
	kind := ErrMalformed
	switch {
	case errors.As(err, &dup):
		kind = ErrDupKey
	case errors.As(err, &indef):
		kind = ErrIndefinite
	case errors.As(err, &tags):
		kind = ErrTag
	case errors.As(err, &nested):
		kind = ErrDepth
	case errors.As(err, &arr), errors.As(err, &mp):
		kind = ErrSize
	case errors.As(err, &extra):
		kind = ErrTrailing
	case errors.As(err, &unacc):
		kind = ErrSimple
	case errors.As(err, &keyType):
		kind = ErrKeyType
	case errors.As(err, &typ):
		kind = ErrFrameShape
	case errors.As(err, &sem):
		kind = ErrUTF8 // единственная семантическая ошибка при выключенных тегах
	case errors.As(err, &syn):
		kind = ErrMalformed
	}
	return &Error{Kind: kind, Err: err}
}

// SequenceReader читает подряд идущие значения CBOR (RFC 8742) — так кадры
// лежат в бинарных дампах. Каждое значение возвращается сырыми байтами и
// проверяется отдельно.
type SequenceReader struct {
	dec *cbor.Decoder
}

// NewSequenceReader создаёт чтение последовательности из r.
func NewSequenceReader(r io.Reader) *SequenceReader {
	return &SequenceReader{dec: decMode.NewDecoder(r)}
}

// Next возвращает следующее значение или io.EOF.
func (s *SequenceReader) Next() ([]byte, error) {
	var raw cbor.RawMessage
	if err := s.dec.Decode(&raw); err != nil {
		if errors.Is(err, io.EOF) {
			return nil, io.EOF
		}
		return nil, classify(err)
	}
	return raw, nil
}
