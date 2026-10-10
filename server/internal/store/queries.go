package store

import (
	"context"
	"crypto/subtle"
	"database/sql"
	"errors"
)

// Ключи server_meta.
const (
	MetaName    = "name"
	MetaCreated = "created"
)

// Meta читает значение server_meta; нет — ("", false).
func (s *Store) Meta(ctx context.Context, key string) (string, bool, error) {
	var v []byte
	err := s.DB.QueryRowContext(ctx, "SELECT value FROM server_meta WHERE key = ?", key).Scan(&v)
	if errors.Is(err, sql.ErrNoRows) {
		return "", false, nil
	}
	return string(v), err == nil, err
}

// SetMeta записывает значение server_meta.
func (s *Store) SetMeta(ctx context.Context, key, value string) error {
	_, err := s.DB.ExecContext(ctx,
		"INSERT INTO server_meta(key, value) VALUES(?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
		key, []byte(value))
	return err
}

// TouchMember добавляет участника или обновляет last_seen. true — новый.
func (s *Store) TouchMember(ctx context.Context, master []byte, now int64) (bool, error) {
	res, err := s.DB.ExecContext(ctx,
		"INSERT INTO members(master_pub, first_seen, last_seen) VALUES(?, ?, ?) ON CONFLICT(master_pub) DO NOTHING",
		master, now, now)
	if err != nil {
		return false, err
	}
	if n, _ := res.RowsAffected(); n == 1 {
		return true, nil
	}
	_, err = s.DB.ExecContext(ctx, "UPDATE members SET last_seen = ? WHERE master_pub = ?", now, master)
	return false, err
}

// Owner — главный ключ владельца или nil.
func (s *Store) Owner(ctx context.Context) ([]byte, error) {
	var m []byte
	err := s.DB.QueryRowContext(ctx, `SELECT mr.master_pub FROM member_roles mr
		JOIN roles r ON r.id = mr.role_id WHERE r.builtin = 'owner' LIMIT 1`).Scan(&m)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	return m, err
}

// Role — роль из базы.
type Role struct {
	ID       int64
	Name     string
	Position int64
	Perms    uint64
	Builtin  string
}

// Roles — все роли по позиции.
func (s *Store) Roles(ctx context.Context) ([]Role, error) {
	rows, err := s.DB.QueryContext(ctx, "SELECT id, name, position, perms, coalesce(builtin, '') FROM roles ORDER BY position")
	if err != nil {
		return nil, err
	}
	defer func() { _ = rows.Close() }()
	var out []Role
	for rows.Next() {
		var r Role
		var perms int64
		if err := rows.Scan(&r.ID, &r.Name, &r.Position, &perms, &r.Builtin); err != nil {
			return nil, err
		}
		r.Perms = uint64(perms) // #nosec G115 -- маска хранится как int64 бит в бит
		out = append(out, r)
	}
	return out, rows.Err()
}

// ClaimOwner проверяет ключ администратора и передаёт роль Владельца
// участнику master: прежний владелец её теряет, ключ сгорает, в журнал
// пишется смена владельца. Всё — одной транзакцией. Неверный ключ — false.
func (s *Store) ClaimOwner(ctx context.Context, tokenHash, master []byte, now int64) (previous []byte, ok bool, err error) {
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return nil, false, err
	}
	defer func() { _ = tx.Rollback() }()

	var stored []byte
	err = tx.QueryRowContext(ctx, "SELECT hash FROM admin_tokens WHERE used_at IS NULL LIMIT 1").Scan(&stored)
	if errors.Is(err, sql.ErrNoRows) || (err == nil && subtle.ConstantTimeCompare(stored, tokenHash) != 1) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, err
	}
	_ = tx.QueryRowContext(ctx, `SELECT mr.master_pub FROM member_roles mr
		JOIN roles r ON r.id = mr.role_id WHERE r.builtin = 'owner' LIMIT 1`).Scan(&previous)
	steps := []struct {
		q    string
		args []any
	}{
		{"UPDATE admin_tokens SET used_at = ? WHERE hash = ?", []any{now, stored}},
		{"DELETE FROM member_roles WHERE role_id = (SELECT id FROM roles WHERE builtin = 'owner')", nil},
		{"INSERT INTO member_roles(master_pub, role_id) SELECT ?, id FROM roles WHERE builtin = 'owner'", []any{master}},
		{"INSERT INTO server_log(at, kind, actor, data) VALUES(?, 'owner.change', ?, ?)", []any{now, master, previous}},
	}
	for _, st := range steps {
		if _, err := tx.ExecContext(ctx, st.q, st.args...); err != nil {
			return nil, false, err
		}
	}
	return previous, true, tx.Commit()
}

// SetAdminToken заменяет ключ администратора: действует только последний.
func (s *Store) SetAdminToken(ctx context.Context, hash []byte, now int64) error {
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(ctx, "DELETE FROM admin_tokens WHERE used_at IS NULL"); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO admin_tokens(hash, created) VALUES(?, ?)", hash, now); err != nil {
		return err
	}
	if _, err := tx.ExecContext(ctx, "INSERT INTO server_log(at, kind) VALUES(?, 'admin_token.issue')", now); err != nil {
		return err
	}
	return tx.Commit()
}

// HasActiveAdminToken — есть ли неиспользованный ключ администратора.
func (s *Store) HasActiveAdminToken(ctx context.Context) (bool, error) {
	var n int
	err := s.DB.QueryRowContext(ctx, "SELECT count(*) FROM admin_tokens WHERE used_at IS NULL").Scan(&n)
	return n > 0, err
}

// SaveDeviceCert запоминает сертификат устройства.
func (s *Store) SaveDeviceCert(ctx context.Context, device, master, signed []byte, created int64) error {
	_, err := s.DB.ExecContext(ctx, `INSERT INTO device_certs(device_pub, master_pub, signed, created) VALUES(?, ?, ?, ?)
		ON CONFLICT(device_pub) DO NOTHING`, device, master, signed, created)
	return err
}

// IsRevoked — отозвано ли устройство.
func (s *Store) IsRevoked(ctx context.Context, device []byte) (bool, error) {
	var n int
	err := s.DB.QueryRowContext(ctx, "SELECT count(*) FROM revoked_devices WHERE device_pub = ?", device).Scan(&n)
	return n > 0, err
}

// Signed — подписанный конверт с seq.
type Signed struct {
	Seq    uint64
	Signed []byte
}

func (s *Store) signedBySeq(ctx context.Context, table string, master []byte) (*Signed, error) {
	var seq int64
	var b []byte
	err := s.DB.QueryRowContext(ctx, "SELECT seq, signed FROM "+table+" WHERE master_pub = ?", master).Scan(&seq, &b) // #nosec G202 -- имя таблицы из кода
	if errors.Is(err, sql.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &Signed{Seq: uint64(seq), Signed: b}, nil // #nosec G115 -- seq ≥ 0 по проверке payload
}

// Profile — последний профиль участника или nil.
func (s *Store) Profile(ctx context.Context, master []byte) (*Signed, error) {
	return s.signedBySeq(ctx, "profiles", master)
}

// Devices — последний список устройств участника или nil.
func (s *Store) Devices(ctx context.Context, master []byte) (*Signed, error) {
	return s.signedBySeq(ctx, "device_lists", master)
}

// SaveProfile сохраняет профиль, если его seq больше сохранённого (или профиля
// ещё нет). Иначе — ErrStale.
func (s *Store) SaveProfile(ctx context.Context, master []byte, seq uint64, signed []byte, now int64) error {
	res, err := s.DB.ExecContext(ctx, `INSERT INTO profiles(master_pub, seq, signed, updated) VALUES(?, ?, ?, ?)
		ON CONFLICT(master_pub) DO UPDATE SET seq = excluded.seq, signed = excluded.signed, updated = excluded.updated
		WHERE excluded.seq > profiles.seq`, master, int64(seq), signed, now) // #nosec G115 -- seq в int64 по профилю CBOR
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrStale
	}
	return nil
}

// SaveDevices сохраняет список устройств с бо́льшим seq и отзывает перечисленные
// в revoked. Иначе — ErrStale.
func (s *Store) SaveDevices(ctx context.Context, master []byte, seq uint64, signed []byte, revoked [][]byte, now int64) error {
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	res, err := tx.ExecContext(ctx, `INSERT INTO device_lists(master_pub, seq, signed) VALUES(?, ?, ?)
		ON CONFLICT(master_pub) DO UPDATE SET seq = excluded.seq, signed = excluded.signed
		WHERE excluded.seq > device_lists.seq`, master, int64(seq), signed) // #nosec G115 -- seq в int64
	if err != nil {
		return err
	}
	if n, _ := res.RowsAffected(); n == 0 {
		return ErrStale
	}
	for _, d := range revoked {
		if err := revokeTx(ctx, tx, d, master, now); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// Revoke отзывает устройство.
func (s *Store) Revoke(ctx context.Context, device, master []byte, now int64) error {
	tx, err := s.DB.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()
	if err := revokeTx(ctx, tx, device, master, now); err != nil {
		return err
	}
	return tx.Commit()
}

func revokeTx(ctx context.Context, tx *sql.Tx, device, master []byte, now int64) error {
	_, err := tx.ExecContext(ctx, `INSERT INTO revoked_devices(device_pub, master_pub, at) VALUES(?, ?, ?)
		ON CONFLICT(device_pub) DO NOTHING`, device, master, now)
	return err
}

// LogEntry — запись журнала сервера.
type LogEntry struct {
	At    int64
	Kind  string
	Actor []byte
	Data  []byte
}

// Log — последние записи журнала.
func (s *Store) Log(ctx context.Context, limit int) ([]LogEntry, error) {
	rows, err := s.DB.QueryContext(ctx, "SELECT at, kind, actor, data FROM server_log ORDER BY id DESC LIMIT ?", limit)
	if err != nil {
		return nil, err
	}
	defer func() { _ = rows.Close() }()
	var out []LogEntry
	for rows.Next() {
		var e LogEntry
		if err := rows.Scan(&e.At, &e.Kind, &e.Actor, &e.Data); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
