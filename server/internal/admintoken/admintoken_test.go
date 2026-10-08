package admintoken

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestFormat(t *testing.T) {
	for range 50 {
		tok, err := New()
		if err != nil {
			t.Fatal(err)
		}
		if !Valid(tok) || len(tok) != len(Prefix)+Len {
			t.Fatalf("%q: неверный формат", tok)
		}
	}
	// Крайние значения: все нули и все единицы помещаются в 43 знака.
	if got := Encode(make([]byte, 32)); got != Prefix+strings.Repeat("0", Len) {
		t.Fatalf("нули: %s", got)
	}
	if !Valid(Encode(bytes.Repeat([]byte{0xff}, 32))) {
		t.Fatal("единицы не помещаются в 43 знака")
	}
	for _, bad := range []string{"", Prefix, "ylat-" + strings.Repeat("a", Len), Prefix + strings.Repeat("a", Len-1), Prefix + strings.Repeat("a", Len-1) + "_"} {
		if Valid(bad) {
			t.Errorf("%q принят", bad)
		}
	}
}

func TestHashTrimsSpace(t *testing.T) {
	tok, _ := New()
	if !bytes.Equal(Hash(tok), Hash(" "+tok+"\n")) {
		t.Fatal("пробелы при вставке меняют хеш")
	}
}

func TestFile0600(t *testing.T) {
	p := filepath.Join(t.TempDir(), "admin-token")
	tok, _ := New()
	if err := WriteFile(p, tok); err != nil {
		t.Fatal(err)
	}
	st, err := os.Stat(p)
	if err != nil {
		t.Fatal(err)
	}
	if st.Mode().Perm() != 0o600 {
		t.Fatalf("права %v", st.Mode().Perm())
	}
	if err := RemoveFile(p); err != nil {
		t.Fatal(err)
	}
	if err := RemoveFile(p); err != nil {
		t.Fatal("повторное удаление:", err)
	}
}
