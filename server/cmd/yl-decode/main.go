// Команда yl-decode переводит кадры CBOR из логов и дампов в читаемый JSON
// (представление spec/json-debug.md).
//
//	yl-decode [флаги] [файл…]      без файлов читает stdin
//
// Вход (--in):
//
//	raw     последовательность значений CBOR подряд (RFC 8742)
//	hex     по кадру в строке, hex
//	base64  по кадру в строке, base64 или base64url
//	auto    построчно hex или base64, если вход — печатный текст; иначе raw
//
// В построчном режиме префикс строки лога пропускается: берётся последнее
// поле строки (через пробел или «=»), которое разбирается как CBOR.
package main

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"unicode"
	"unicode/utf8"

	"yeenlink/server/pkg/codec"
)

type options struct {
	in      string
	compact bool
	hex     bool
}

func main() {
	var opt options
	flag.StringVar(&opt.in, "in", "auto", "формат входа: auto, raw, hex, base64")
	flag.BoolVar(&opt.compact, "compact", false, "по кадру в строке, без отступов")
	flag.BoolVar(&opt.hex, "hex", false, "байты показывать в hex (такой JSON не читается обратно)")
	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, "yl-decode — кадры CBOR в читаемый JSON\n\nИспользование: yl-decode [флаги] [файл…]")
		flag.PrintDefaults()
	}
	flag.Parse()

	inputs := flag.Args()
	if len(inputs) == 0 {
		inputs = []string{"-"}
	}
	failed := false
	for _, name := range inputs {
		data, err := readInput(name)
		if err != nil {
			fmt.Fprintln(os.Stderr, "yl-decode:", err)
			os.Exit(2)
		}
		if err := run(data, opt, os.Stdout, os.Stderr); err != nil {
			fmt.Fprintf(os.Stderr, "yl-decode: %s: %v\n", name, err)
			failed = true
		}
	}
	if failed {
		os.Exit(1)
	}
}

func readInput(name string) ([]byte, error) {
	if name == "-" {
		return io.ReadAll(os.Stdin)
	}
	return os.ReadFile(name)
}

// run декодирует вход и пишет JSON в out. Ошибки отдельных кадров идут в
// errOut, а итоговая ошибка сообщает, что такие были.
func run(data []byte, opt options, out, errOut io.Writer) error {
	var items [][]byte
	var err error
	switch opt.in {
	case "raw":
		items, err = readRaw(data)
	case "hex", "base64":
		items, err = readLines(data, opt.in, errOut)
	case "auto":
		// Текст из печатных символов — это hex или base64 из лога. Бинарный
		// кадр CBOR начинается с заголовка словаря (0xa0…), а это не UTF-8.
		if isText(data) {
			items, err = readLines(data, "auto", errOut)
		} else {
			items, err = readRaw(data)
		}
	default:
		return fmt.Errorf("неизвестный формат входа %q", opt.in)
	}
	if err != nil {
		return err
	}

	jopt := codec.JSONOptions{Indent: "  ", BytesHex: opt.hex}
	if opt.compact {
		jopt.Indent = ""
	}
	bad := 0
	for i, item := range items {
		js, err := codec.ToJSON(item, jopt)
		if err != nil {
			fmt.Fprintf(errOut, "кадр %d: %v\n", i+1, err)
			bad++
			continue
		}
		fmt.Fprintf(out, "%s\n", js)
	}
	if bad > 0 {
		return fmt.Errorf("не разобрано кадров: %d", bad)
	}
	return nil
}

func isText(data []byte) bool {
	if !utf8.Valid(data) {
		return false
	}
	for _, r := range string(data) {
		if !unicode.IsPrint(r) && !unicode.IsSpace(r) {
			return false
		}
	}
	return true
}

func readRaw(data []byte) ([][]byte, error) {
	if len(bytes.TrimSpace(data)) == 0 {
		return nil, errors.New("пустой вход")
	}
	var items [][]byte
	seq := codec.NewSequenceReader(bytes.NewReader(data))
	for {
		item, err := seq.Next()
		if errors.Is(err, io.EOF) {
			return items, nil
		}
		if err != nil {
			return nil, err
		}
		if err := codec.Validate(item); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
}

func readLines(data []byte, mode string, errOut io.Writer) ([][]byte, error) {
	var items [][]byte
	sc := bufio.NewScanner(bytes.NewReader(data))
	sc.Buffer(make([]byte, 0, 64*1024), 16<<20)
	for n := 1; sc.Scan(); n++ {
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		item, ok := frameInLine(line, mode)
		if !ok {
			fmt.Fprintf(errOut, "строка %d: кадр не найден\n", n)
			continue
		}
		items = append(items, item)
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	if len(items) == 0 {
		return nil, errors.New("во входе нет кадров")
	}
	return items, nil
}

func frameInLine(line, mode string) ([]byte, bool) {
	fields := strings.FieldsFunc(line, func(r rune) bool { return r == ' ' || r == '\t' || r == '=' })
	for i := len(fields) - 1; i >= 0; i-- {
		for _, b := range decodeField(strings.Trim(fields[i], `"'`), mode) {
			if codec.Validate(b) == nil {
				return b, true
			}
		}
	}
	return nil, false
}

func decodeField(f, mode string) [][]byte {
	var out [][]byte
	if mode == "hex" || mode == "auto" {
		if b, err := hex.DecodeString(f); err == nil {
			out = append(out, b)
		}
	}
	if mode == "base64" || mode == "auto" {
		for _, enc := range []*base64.Encoding{base64.StdEncoding, base64.RawStdEncoding, base64.URLEncoding, base64.RawURLEncoding} {
			if b, err := enc.DecodeString(f); err == nil {
				out = append(out, b)
				break
			}
		}
	}
	return out
}
