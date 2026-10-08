package serverkey

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCreateThenLoad(t *testing.T) {
	p := filepath.Join(t.TempDir(), "server.key")
	k1, created, err := LoadOrCreate(p)
	if err != nil || !created {
		t.Fatal(created, err)
	}
	st, _ := os.Stat(p)
	if st.Mode().Perm() != 0o600 {
		t.Fatalf("права %v", st.Mode().Perm())
	}
	k2, created, err := LoadOrCreate(p)
	if err != nil || created {
		t.Fatal(created, err)
	}
	if !k1.Equal(k2) {
		t.Fatal("ключ изменился")
	}
}

func TestRefusesWidePerms(t *testing.T) {
	p := filepath.Join(t.TempDir(), "server.key")
	if _, _, err := LoadOrCreate(p); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(p, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, _, err := LoadOrCreate(p); err == nil {
		t.Fatal("ключ с правами 0644 принят")
	}
}
