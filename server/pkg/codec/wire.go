package codec

import "fmt"

// Wire — формат кадров на проводе. Внутри всегда CBOR; JSON — отладочный
// режим сервера (--codec=json), тот же кадр в представлении json-debug.
type Wire int

// Форматы на проводе: CBOR — рабочий, JSON — отладочный.
const (
	WireCBOR Wire = iota
	WireJSON
)

// ParseWire разбирает значение флага --codec.
func ParseWire(s string) (Wire, error) {
	switch s {
	case "cbor":
		return WireCBOR, nil
	case "json":
		return WireJSON, nil
	}
	return 0, fmt.Errorf("codec: неизвестный формат %q, ожидается cbor или json", s)
}

func (w Wire) String() string {
	if w == WireJSON {
		return "json"
	}
	return "cbor"
}

// EncodeFrame кодирует кадр для отправки.
func (w Wire) EncodeFrame(f *Frame) ([]byte, error) {
	b, err := f.Encode()
	if err != nil || w == WireCBOR {
		return b, err
	}
	return ToJSON(b, JSONOptions{})
}

// DecodeFrame разбирает принятый кадр.
func (w Wire) DecodeFrame(data []byte) (*Frame, error) {
	if w == WireJSON {
		b, err := FromJSON(data)
		if err != nil {
			return nil, err
		}
		data = b
	}
	return DecodeFrame(data)
}
