// Package store — SQLite сервера: миграции и запросы (spec/server.md,
// «Хранение»). Драйвер modernc.org/sqlite — чистый Go, бинарник остаётся
// статическим.
package store

import (
	"context"
	"database/sql"
	"embed"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"sort"
	"strconv"
	"strings"

	_ "modernc.org/sqlite" // драйвер "sqlite"
)

//go:embed migrations/*.sql
var migrations embed.FS

// migrationFS — откуда берутся миграции (тест подставляет свои).
var migrationFS fs.FS = migrations

// Store — база сервера.
type Store struct {
	DB   *sql.DB
	path string
}

// Open открывает базу, включает WAL и применяет миграции. Перед повышением
// версии делает снимок базы рядом: <path>.bak-v<старая версия>.
func Open(ctx context.Context, path string) (*Store, error) {
	// Файл базы — 0600 (журналы WAL SQLite создаёт с теми же правами).
	if f, err := os.OpenFile(path, os.O_RDONLY|os.O_CREATE, 0o600); err == nil {
		_ = f.Close()
	} else {
		return nil, err
	}
	dsn := "file:" + path + "?_pragma=journal_mode(WAL)&_pragma=synchronous(NORMAL)" +
		"&_pragma=foreign_keys(ON)&_pragma=busy_timeout(5000)&_pragma=cache_size(-8000)"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	// SQLite пишет одним соединением; читатели в WAL не мешают.
	db.SetMaxOpenConns(4)
	s := &Store{DB: db, path: path}
	if err := s.migrate(ctx); err != nil {
		_ = db.Close()
		return nil, err
	}
	return s, nil
}

// Close закрывает базу.
func (s *Store) Close() error { return s.DB.Close() }

// Version — текущая версия схемы (PRAGMA user_version).
func (s *Store) Version(ctx context.Context) (int, error) {
	var v int
	err := s.DB.QueryRowContext(ctx, "PRAGMA user_version").Scan(&v)
	return v, err
}

type migration struct {
	version int
	name    string
	sql     string
}

func loadMigrations() ([]migration, error) {
	entries, err := fs.ReadDir(migrationFS, "migrations")
	if err != nil {
		return nil, err
	}
	var out []migration
	for _, e := range entries {
		num, _, ok := strings.Cut(e.Name(), "_")
		v, err := strconv.Atoi(num)
		if !ok || err != nil {
			return nil, fmt.Errorf("store: имя миграции %q — нужно NNNN_описание.sql", e.Name())
		}
		b, err := fs.ReadFile(migrationFS, "migrations/"+e.Name())
		if err != nil {
			return nil, err
		}
		out = append(out, migration{v, e.Name(), string(b)})
	}
	sort.Slice(out, func(i, j int) bool { return out[i].version < out[j].version })
	for i, m := range out {
		if m.version != i+1 {
			return nil, fmt.Errorf("store: миграции должны идти подряд с 0001, а %s под номером %d", m.name, i+1)
		}
	}
	return out, nil
}

// Latest — версия схемы, которую знает этот бинарник.
func Latest() int {
	ms, err := loadMigrations()
	if err != nil {
		panic(err)
	}
	return len(ms)
}

func (s *Store) migrate(ctx context.Context) error {
	ms, err := loadMigrations()
	if err != nil {
		return err
	}
	cur, err := s.Version(ctx)
	if err != nil {
		return err
	}
	if cur > len(ms) {
		return fmt.Errorf("store: база версии %d новее этого сервера (знает до %d) — обновите ylsrv", cur, len(ms))
	}
	if cur == len(ms) {
		return nil
	}
	if cur > 0 {
		if err := s.snapshot(ctx, cur); err != nil {
			return fmt.Errorf("store: снимок перед миграцией: %w", err)
		}
	}
	for _, m := range ms[cur:] {
		tx, err := s.DB.BeginTx(ctx, nil)
		if err != nil {
			return err
		}
		if _, err := tx.ExecContext(ctx, m.sql); err != nil {
			_ = tx.Rollback()
			return fmt.Errorf("store: миграция %s: %w", m.name, err)
		}
		if _, err := tx.ExecContext(ctx, fmt.Sprintf("PRAGMA user_version = %d", m.version)); err != nil {
			_ = tx.Rollback()
			return err
		}
		if err := tx.Commit(); err != nil {
			return err
		}
	}
	return nil
}

func (s *Store) snapshot(ctx context.Context, version int) error {
	dst := fmt.Sprintf("%s.bak-v%d", s.path, version)
	if _, err := os.Stat(dst); err == nil {
		return nil // снимок этой версии уже есть
	}
	// VACUUM INTO пишет и в пустой файл — создаём его сами, чтобы права были 0600.
	f, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return err
	}
	_ = f.Close()
	if _, err := s.DB.ExecContext(ctx, "VACUUM INTO ?", dst); err != nil {
		_ = os.Remove(dst)
		return err
	}
	return nil
}

// ErrStale — запись с не бо́льшим seq, чем уже сохранённая.
var ErrStale = errors.New("store: seq не больше сохранённого")
