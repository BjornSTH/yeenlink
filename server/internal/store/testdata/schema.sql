CREATE TABLE admin_tokens (
  hash    BLOB PRIMARY KEY CHECK (length(hash) = 32),
  created INTEGER NOT NULL,
  used_at INTEGER
) STRICT;
CREATE TABLE device_certs (
  device_pub BLOB PRIMARY KEY CHECK (length(device_pub) = 32),
  master_pub BLOB NOT NULL,
  signed     BLOB NOT NULL,
  created    INTEGER NOT NULL
) STRICT;
CREATE TABLE device_lists (
  master_pub BLOB PRIMARY KEY,
  seq        INTEGER NOT NULL,
  signed     BLOB NOT NULL
) STRICT;
CREATE TABLE member_roles (
  master_pub BLOB NOT NULL REFERENCES members(master_pub) ON DELETE CASCADE,
  role_id    INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  PRIMARY KEY (master_pub, role_id)
) STRICT;
CREATE TABLE members (
  master_pub BLOB PRIMARY KEY CHECK (length(master_pub) = 32),
  first_seen INTEGER NOT NULL,
  last_seen  INTEGER NOT NULL
) STRICT;
CREATE TABLE profiles (
  master_pub BLOB PRIMARY KEY,
  seq        INTEGER NOT NULL,
  signed     BLOB NOT NULL,
  updated    INTEGER NOT NULL
) STRICT;
CREATE TABLE revoked_devices (
  device_pub BLOB PRIMARY KEY,
  master_pub BLOB NOT NULL,
  at         INTEGER NOT NULL
) STRICT;
CREATE TABLE roles (
  id       INTEGER PRIMARY KEY,
  name     TEXT NOT NULL,
  position INTEGER NOT NULL,
  perms    INTEGER NOT NULL,
  builtin  TEXT UNIQUE CHECK (builtin IN ('everyone', 'owner'))
) STRICT;
CREATE TABLE server_log (
  id    INTEGER PRIMARY KEY,
  at    INTEGER NOT NULL,
  kind  TEXT NOT NULL,
  actor BLOB,
  data  BLOB
) STRICT;
CREATE TABLE server_meta (
  key   TEXT PRIMARY KEY,
  value BLOB NOT NULL
) STRICT;
CREATE INDEX device_certs_master ON device_certs(master_pub);
CREATE INDEX server_log_at ON server_log(at);
