package codec

import (
	"math"

	"github.com/fxamacker/cbor/v2"
)

// Frame — кадр протокола клиент–сервер (spec/frame.cddl).
//
// Запрос клиента несёт ID; ответ сервера — тот же ID и либо D, либо E.
// События сервера идут без ID. D хранится сырыми байтами CBOR: обработчик
// операции сам разбирает его в свою структуру через DecodeD.
type Frame struct {
	Op string
	ID *uint64
	D  []byte // CBOR; nil — поля нет
	E  *FrameError
}

// FrameError — ошибка в ответе сервера.
type FrameError struct {
	Code string `cbor:"code"`
	Msg  string `cbor:"msg"`
}

type wireFrame struct {
	Op string          `cbor:"op"`
	ID *uint64         `cbor:"id,omitempty"`
	D  cbor.RawMessage `cbor:"d,omitempty"`
	E  *FrameError     `cbor:"e,omitempty"`
}

// NewFrame собирает кадр, кодируя d в CBOR. d == nil — кадр без поля d.
func NewFrame(op string, id *uint64, d any) (*Frame, error) {
	f := &Frame{Op: op, ID: id}
	if d != nil {
		b, err := Marshal(d)
		if err != nil {
			return nil, err
		}
		f.D = b
	}
	return f, nil
}

// ID возвращает указатель на id запроса — для краткости при сборке кадров.
func ID(id uint64) *uint64 { return &id }

// DecodeD разбирает поле d в v.
func (f *Frame) DecodeD(v any) error {
	if f.D == nil {
		return errf(ErrFrameShape, "в кадре %q нет поля d", f.Op)
	}
	return Unmarshal(f.D, v)
}

// Encode кодирует кадр в CBOR.
func (f *Frame) Encode() ([]byte, error) {
	if err := f.check(); err != nil {
		return nil, err
	}
	return Marshal(wireFrame{Op: f.Op, ID: f.ID, D: f.D, E: f.E})
}

// DecodeFrame разбирает и проверяет кадр CBOR.
func DecodeFrame(data []byte) (*Frame, error) {
	v, err := Decode(data)
	if err != nil {
		return nil, err
	}
	if _, ok := v.(map[string]any); !ok {
		return nil, errf(ErrFrameShape, "кадр должен быть словарём")
	}
	var w wireFrame
	if err := decMode.Unmarshal(data, &w); err != nil {
		return nil, classify(err)
	}
	f := &Frame{Op: w.Op, ID: w.ID, E: w.E}
	if w.D != nil {
		f.D = []byte(w.D)
	}
	if err := f.check(); err != nil {
		return nil, err
	}
	return f, nil
}

func (f *Frame) check() error {
	switch {
	case f.Op == "":
		return errf(ErrFrameShape, "нет op")
	case f.ID != nil && *f.ID > math.MaxInt64:
		return errf(ErrIntRange, "id больше int64")
	case f.D != nil && f.E != nil:
		return errf(ErrFrameShape, "в кадре одновременно d и e")
	case f.E != nil && f.E.Code == "":
		return errf(ErrFrameShape, "в ошибке нет code")
	}
	return nil
}
