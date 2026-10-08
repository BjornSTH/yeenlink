import 'dart:typed_data';

import '../codec/codec.dart';
import '../identity/identity.dart';

/// Ответы и события фазы 2 (spec/auth.cddl). Разбор строгий: поле не того
/// типа — [CodecException] с [CodecErrorKind.frameShape].

Never _bad(String what) => throw CodecException(CodecErrorKind.frameShape, what);

Map<String, Object?> _map(Object? v, String what) =>
    v is Map<String, Object?> ? v : _bad('$what: нужен словарь');

T _req<T extends Object>(Map<String, Object?> m, String k) {
  final v = m[k];
  if (v is T) return v;
  _bad('$k: не тот тип');
}

T? _opt<T extends Object>(Map<String, Object?> m, String k) {
  final v = m[k];
  if (v == null) return null;
  if (v is T) return v;
  _bad('$k: не тот тип');
}

Signed? _signed(Map<String, Object?> m, String k) {
  final b = _opt<Uint8List>(m, k);
  return b == null ? null : Signed.decode(b);
}

/// Бит OWNER (docs/spec.md, «Биты»). Маски приходят int64 в дополнительном
/// коде: 64-битный int Dart хранит те же биты.
const int permOwner = 1 << 63;

bool hasPerm(int mask, int bit) => mask & bit != 0;

/// Сервер в ready и server.update.
class ServerState {
  ServerState.fromMap(Map<String, Object?> m)
    : pub = _req<Uint8List>(m, 'pub'),
      name = _req<String>(m, 'name'),
      version = _req<String>(m, 'version'),
      hasOwner = _req<bool>(m, 'has_owner'),
      info = Signed.decode(_req<Uint8List>(m, 'info'));

  final Uint8List pub;
  final String name;
  final String version;
  final bool hasOwner;

  /// Подписанный server_info.
  final Signed info;
}

/// Я на этом сервере.
class Me {
  Me.fromMap(Map<String, Object?> m)
    : masterPub = _req<Uint8List>(m, 'master_pub'),
      owner = _req<bool>(m, 'owner'),
      profile = _signed(m, 'profile'),
      devices = _signed(m, 'devices');

  final Uint8List masterPub;
  final bool owner;

  /// Последние принятые сервером профиль и список устройств.
  final Signed? profile;
  final Signed? devices;
}

class SessionInfo {
  SessionInfo.fromMap(Map<String, Object?> m)
    : id = _req<Uint8List>(m, 'id'),
      resumeMs = _req<int>(m, 'resume_ms');

  final Uint8List id;
  final int resumeMs;
}

class Role {
  Role.fromMap(Map<String, Object?> m)
    : id = _req<int>(m, 'id'),
      name = _req<String>(m, 'name'),
      position = _req<int>(m, 'position'),
      perms = _req<int>(m, 'perms'),
      builtin = _opt<String>(m, 'builtin');

  final int id;
  final String name;
  final int position;
  final int perms;

  /// `everyone` или `owner`.
  final String? builtin;
}

class Ready {
  Ready.fromMap(Map<String, Object?> m)
    : server = ServerState.fromMap(_map(m['server'], 'server')),
      me = Me.fromMap(_map(m['me'], 'me')),
      session = SessionInfo.fromMap(_map(m['session'], 'session')),
      roles = [for (final r in _req<List<Object?>>(m, 'roles')) Role.fromMap(_map(r, 'role'))],
      permsServer = _req<int>(_map(m['perms'], 'perms'), 'server'),
      lastEvent = _req<int>(m, 'last_event');

  factory Ready.decode(Frame f) => Ready.fromMap(_map(f.decodeD(), 'ready'));

  final ServerState server;
  final Me me;
  final SessionInfo session;
  final List<Role> roles;
  final int permsServer;
  final int lastEvent;
}

class Resumed {
  Resumed.fromMap(Map<String, Object?> m)
    : session = SessionInfo.fromMap(_map(m['session'], 'session')),
      events = [
        for (final e in _req<List<Object?>>(m, 'events'))
          Frame.decode(e is Uint8List ? e : _bad('events: нужны байты')),
      ],
      lastEvent = _req<int>(m, 'last_event');

  factory Resumed.decode(Frame f) => Resumed.fromMap(_map(f.decodeD(), 'resumed'));

  final SessionInfo session;

  /// Пропущенные события по порядку.
  final List<Frame> events;
  final int lastEvent;
}

class MemberUpdate {
  MemberUpdate.fromMap(Map<String, Object?> m)
    : masterPub = _req<Uint8List>(m, 'master_pub'),
      owner = _req<bool>(m, 'owner'),
      profile = _signed(m, 'profile');

  factory MemberUpdate.decode(Frame f) => MemberUpdate.fromMap(_map(f.decodeD(), 'member.update'));

  final Uint8List masterPub;
  final bool owner;
  final Signed? profile;
}

ServerState serverUpdate(Frame f) =>
    ServerState.fromMap(_map(_map(f.decodeD(), 'server.update')['server'], 'server'));

/// `{seq}` — ответ на profile.push и devices.push.
int seqAck(Object? d) => _req<int>(_map(d, 'seq'), 'seq');
