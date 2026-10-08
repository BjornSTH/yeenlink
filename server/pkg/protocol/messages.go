package protocol

// Кадры после входа (spec/auth.md, «Кадры фазы 2»). Подписанные конверты
// (профиль, сертификат, списки) передаются CBOR-байтами Signed как есть.

// Server — сервер в ready и server.update.
type Server struct {
	Pub      []byte `cbor:"pub"`
	Name     string `cbor:"name"`
	Version  string `cbor:"version"`
	HasOwner bool   `cbor:"has_owner"`
	// Info — подписанный server_info (тот же, что в /.well-known/yeenlink).
	Info []byte `cbor:"info"`
}

// Me — вошедший участник.
type Me struct {
	MasterPub []byte `cbor:"master_pub"`
	Owner     bool   `cbor:"owner"`
	// Profile и Devices — последние, что знает сервер; клиент по ним заменяет
	// локальный профиль с seq 0 и выбирает seq для нового списка устройств.
	Profile []byte `cbor:"profile,omitempty"`
	Devices []byte `cbor:"devices,omitempty"`
}

// Session — сессия для resume.
type Session struct {
	ID       []byte `cbor:"id"`
	ResumeMs uint64 `cbor:"resume_ms"`
}

// Role — роль (в фазе 2 только встроенные «все» и «Владелец»).
type Role struct {
	ID       uint64 `cbor:"id"`
	Name     string `cbor:"name"`
	Position uint64 `cbor:"position"`
	Perms    uint64 `cbor:"perms"`
	Builtin  string `cbor:"builtin,omitempty"` // everyone | owner
}

// Perms — готовые права: серверные биты и маски по каналам (каналы — фаза 3).
type Perms struct {
	Server   uint64            `cbor:"server"`
	Channels map[string]uint64 `cbor:"channels"`
}

// Ready — ответ на auth без resume.
type Ready struct {
	Server    Server  `cbor:"server"`
	Me        Me      `cbor:"me"`
	Session   Session `cbor:"session"`
	Channels  []any   `cbor:"channels"`
	Roles     []Role  `cbor:"roles"`
	Perms     Perms   `cbor:"perms"`
	Addresses []any   `cbor:"addresses"`
	LastEvent uint64  `cbor:"last_event"`
}

// Resumed — ответ на auth с resume: пропущенные события (CBOR кадров) и
// номер последнего.
type Resumed struct {
	Session   Session  `cbor:"session"`
	Events    [][]byte `cbor:"events"`
	LastEvent uint64   `cbor:"last_event"`
}

// AdminClaim — запрос «стать владельцем».
type AdminClaim struct {
	Token string `cbor:"token"`
}

// AdminClaimed — ответ: роль выдана.
type AdminClaimed struct {
	Owner bool `cbor:"owner"`
}

// ProfilePush — профиль (Signed CBOR).
type ProfilePush struct {
	Profile []byte `cbor:"profile"`
}

// SeqAck — ответ на profile.push и devices.push.
type SeqAck struct {
	Seq uint64 `cbor:"seq"`
}

// DevicesPush — список устройств (Signed CBOR).
type DevicesPush struct {
	Devices []byte `cbor:"devices"`
}

// RevokePush — отзыв устройства (Signed CBOR).
type RevokePush struct {
	Revoke []byte `cbor:"revoke"`
}

// ServerUpdate — событие: изменилось имя или появился владелец.
type ServerUpdate struct {
	Server Server `cbor:"server"`
}

// MemberUpdate — событие: у участника новый профиль или роль Владельца.
type MemberUpdate struct {
	MasterPub []byte `cbor:"master_pub"`
	Owner     bool   `cbor:"owner"`
	Profile   []byte `cbor:"profile,omitempty"`
}
