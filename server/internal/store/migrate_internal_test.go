package store

import (
	"context"
	"io/fs"
	"os"
	"path/filepath"
	"testing"
	"testing/fstest"
)

// Новая миграция поверх существующей базы: сначала снимок 0600 со старой
// схемой, затем новая версия.
func TestMigrationSnapshot(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "yeenlink.db")
	s, err := Open(ctx, path)
	if err != nil {
		t.Fatal(err)
	}
	if err := s.SetMeta(ctx, MetaName, "Логово"); err != nil {
		t.Fatal(err)
	}
	_ = s.Close()

	init1, err := fs.ReadFile(migrations, "migrations/0001_init.sql")
	if err != nil {
		t.Fatal(err)
	}
	migrationFS = fstest.MapFS{
		"migrations/0001_init.sql":  {Data: init1},
		"migrations/0002_extra.sql": {Data: []byte("CREATE TABLE extra (id INTEGER PRIMARY KEY) STRICT;")},
	}
	t.Cleanup(func() { migrationFS = migrations })

	s, err = Open(ctx, path)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = s.Close() }()
	if v, _ := s.Version(ctx); v != 2 {
		t.Fatalf("версия %d", v)
	}
	if name, _, _ := s.Meta(ctx, MetaName); name != "Логово" {
		t.Fatalf("данные пропали: %q", name)
	}
	st, err := os.Stat(path + ".bak-v1")
	if err != nil {
		t.Fatal("нет снимка:", err)
	}
	if st.Mode().Perm() != 0o600 {
		t.Fatalf("права снимка %v", st.Mode().Perm())
	}
	if st, _ := os.Stat(path); st.Mode().Perm() != 0o600 {
		t.Fatalf("права базы %v", st.Mode().Perm())
	}

	migrationFS = migrations
	snap, err := Open(ctx, path+".bak-v1")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = snap.Close() }()
	if v, _ := snap.Version(ctx); v != 1 {
		t.Fatalf("снимок версии %d", v)
	}
}
