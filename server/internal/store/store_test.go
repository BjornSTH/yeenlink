package store_test

import (
	"bytes"
	"context"
	"database/sql"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"yeenlink/server/internal/store"
)

func open(t *testing.T) (*store.Store, string) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "yeenlink.db")
	s, err := store.Open(context.Background(), path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })
	return s, path
}

func key(b byte) []byte { return bytes.Repeat([]byte{b}, 32) }

// Схема после всех миграций совпадает с эталоном testdata/schema.sql: любое
// изменение схемы — только новой миграцией и с обновлением эталона
// (UPDATE_SCHEMA=1 go test ./internal/store).
func TestSchemaMatchesGolden(t *testing.T) {
	s, _ := open(t)
	rows, err := s.DB.Query("SELECT sql FROM sqlite_schema WHERE sql IS NOT NULL ORDER BY type DESC, name")
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = rows.Close() }()
	var b strings.Builder
	for rows.Next() {
		var q string
		_ = rows.Scan(&q)
		b.WriteString(q + ";\n")
	}
	golden := filepath.Join("testdata", "schema.sql")
	if os.Getenv("UPDATE_SCHEMA") == "1" {
		_ = os.MkdirAll("testdata", 0o750)
		if err := os.WriteFile(golden, []byte(b.String()), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(golden)
	if err != nil {
		t.Fatalf("нет эталона схемы: UPDATE_SCHEMA=1 go test ./internal/store (%v)", err)
	}
	if b.String() != string(want) {
		t.Fatalf("схема изменилась без обновления эталона:\n%s", b.String())
	}
	if v, _ := s.Version(context.Background()); v != store.Latest() {
		t.Fatalf("версия %d, ожидалась %d", v, store.Latest())
	}
}

func TestReopenKeepsDataAndRefusesNewerSchema(t *testing.T) {
	s, path := open(t)
	ctx := context.Background()
	if err := s.SetMeta(ctx, store.MetaName, "Ночной привал"); err != nil {
		t.Fatal(err)
	}
	_ = s.Close()

	s2, err := store.Open(ctx, path)
	if err != nil {
		t.Fatal(err)
	}
	name, _, _ := s2.Meta(ctx, store.MetaName)
	if name != "Ночной привал" {
		t.Fatalf("имя: %q", name)
	}
	_, _ = s2.DB.Exec("PRAGMA user_version = 999")
	_ = s2.Close()
	if _, err := store.Open(ctx, path); err == nil || !strings.Contains(err.Error(), "новее") {
		t.Fatalf("база новее сервера должна не открыться: %v", err)
	}
}

func TestClaimOwnerTransfersAndLogs(t *testing.T) {
	s, _ := open(t)
	ctx := context.Background()
	for _, m := range [][]byte{key(1), key(2)} {
		if _, err := s.TouchMember(ctx, m, 1); err != nil {
			t.Fatal(err)
		}
	}
	if err := s.SetAdminToken(ctx, key(9), 1); err != nil {
		t.Fatal(err)
	}
	if _, ok, _ := s.ClaimOwner(ctx, key(8), key(1), 2); ok {
		t.Fatal("неверный ключ принят")
	}
	prev, ok, err := s.ClaimOwner(ctx, key(9), key(1), 3)
	if err != nil || !ok || prev != nil {
		t.Fatalf("первый владелец: %v %v %x", ok, err, prev)
	}
	if _, ok, _ := s.ClaimOwner(ctx, key(9), key(2), 4); ok {
		t.Fatal("ключ должен сгореть после использования")
	}
	// Новый ключ передаёт роль: прежний владелец её теряет.
	if err := s.SetAdminToken(ctx, key(7), 5); err != nil {
		t.Fatal(err)
	}
	prev, ok, err = s.ClaimOwner(ctx, key(7), key(2), 6)
	if err != nil || !ok || !bytes.Equal(prev, key(1)) {
		t.Fatalf("передача: %v %v %x", ok, err, prev)
	}
	owner, _ := s.Owner(ctx)
	if !bytes.Equal(owner, key(2)) {
		t.Fatalf("владелец %x", owner)
	}
	log, _ := s.Log(ctx, 10)
	changes := 0
	for _, e := range log {
		if e.Kind == "owner.change" {
			changes++
		}
	}
	if changes != 2 {
		t.Fatalf("смен владельца в журнале: %d", changes)
	}
}

func TestSeqOnlyGrows(t *testing.T) {
	s, _ := open(t)
	ctx := context.Background()
	if err := s.SaveProfile(ctx, key(1), 0, []byte("p0"), 1); err != nil {
		t.Fatal(err)
	}
	if err := s.SaveProfile(ctx, key(1), 0, []byte("again"), 2); !errors.Is(err, store.ErrStale) {
		t.Fatalf("тот же seq: %v", err)
	}
	if err := s.SaveProfile(ctx, key(1), 3, []byte("p3"), 3); err != nil {
		t.Fatal(err)
	}
	if p, _ := s.Profile(ctx, key(1)); p.Seq != 3 || string(p.Signed) != "p3" {
		t.Fatalf("профиль %+v", p)
	}
	if err := s.SaveDevices(ctx, key(1), 1, []byte("d1"), [][]byte{key(5)}, 1); err != nil {
		t.Fatal(err)
	}
	if err := s.SaveDevices(ctx, key(1), 1, []byte("d1"), nil, 1); !errors.Is(err, store.ErrStale) {
		t.Fatalf("тот же seq списка: %v", err)
	}
	if r, _ := s.IsRevoked(ctx, key(5)); !r {
		t.Fatal("устройство из revoked не отозвано")
	}
	if p, err := s.Profile(ctx, key(4)); p != nil || (err != nil && !errors.Is(err, sql.ErrNoRows)) {
		t.Fatalf("нет профиля: %+v %v", p, err)
	}
}
