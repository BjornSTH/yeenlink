-- Фаза 2: сервер, участники, встроенные роли, устройства, профили, ключ
-- администратора, журнал сервера. Времена — unix-время в мс.

CREATE TABLE server_meta (
  key   TEXT PRIMARY KEY,
  value BLOB NOT NULL
) STRICT;

CREATE TABLE members (
  master_pub BLOB PRIMARY KEY CHECK (length(master_pub) = 32),
  first_seen INTEGER NOT NULL,
  last_seen  INTEGER NOT NULL
) STRICT;

-- Роли: маска прав uint64 (бит 63 — OWNER). В фазе 2 только встроенные
-- «все» (everyone) и «Владелец» (owner); свои роли — фаза 3.
CREATE TABLE roles (
  id       INTEGER PRIMARY KEY,
  name     TEXT NOT NULL,
  position INTEGER NOT NULL,
  perms    INTEGER NOT NULL,
  builtin  TEXT UNIQUE CHECK (builtin IN ('everyone', 'owner'))
) STRICT;

CREATE TABLE member_roles (
  master_pub BLOB NOT NULL REFERENCES members(master_pub) ON DELETE CASCADE,
  role_id    INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  PRIMARY KEY (master_pub, role_id)
) STRICT;

-- Сертификаты устройств — подписанные конверты как пришли.
CREATE TABLE device_certs (
  device_pub BLOB PRIMARY KEY CHECK (length(device_pub) = 32),
  master_pub BLOB NOT NULL,
  signed     BLOB NOT NULL,
  created    INTEGER NOT NULL
) STRICT;
CREATE INDEX device_certs_master ON device_certs(master_pub);

-- Последний список устройств участника (seq растёт).
CREATE TABLE device_lists (
  master_pub BLOB PRIMARY KEY,
  seq        INTEGER NOT NULL,
  signed     BLOB NOT NULL
) STRICT;

-- Отозванные устройства: из revoke и из revoked в списке устройств.
CREATE TABLE revoked_devices (
  device_pub BLOB PRIMARY KEY,
  master_pub BLOB NOT NULL,
  at         INTEGER NOT NULL
) STRICT;

-- Последний профиль участника (seq растёт; 0 — локальный после восстановления).
CREATE TABLE profiles (
  master_pub BLOB PRIMARY KEY,
  seq        INTEGER NOT NULL,
  signed     BLOB NOT NULL,
  updated    INTEGER NOT NULL
) STRICT;

-- Ключ администратора: хранится только SHA-256; действует один.
CREATE TABLE admin_tokens (
  hash    BLOB PRIMARY KEY CHECK (length(hash) = 32),
  created INTEGER NOT NULL,
  used_at INTEGER
) STRICT;

-- Журнал сервера: смена владельца и прочие события администрирования
-- (модерация — фаза 7).
CREATE TABLE server_log (
  id    INTEGER PRIMARY KEY,
  at    INTEGER NOT NULL,
  kind  TEXT NOT NULL,
  actor BLOB,
  data  BLOB
) STRICT;
CREATE INDEX server_log_at ON server_log(at);

INSERT INTO roles (id, name, position, perms, builtin) VALUES
  (1, 'Все', 0, 0, 'everyone'),
  (2, 'Владелец', 1000000, -9223372036854775808, 'owner');
