import 'dart:async';
import 'package:flutter/foundation.dart';

import '../db/app_db.dart';
import '../identity/identity.dart';
import '../net/server_address.dart';
import '../net/server_link.dart';
import 'server_connection.dart';

/// Подключение к адресу: в приложении — [ServerLink.connect], в тестах — подмена.
typedef LinkDialer =
    Future<ServerLink> Function(
      ServerAddress addr,
      Uint8List pinned,
      LinkCredentials creds,
      ResumeToken? resume,
    );

/// server_info по адресу: в приложении — [fetchServerInfo].
typedef InfoFetcher = Future<(ServerInfo, Signed)> Function(ServerAddress addr);

Future<ServerLink> _linkConnect(
  ServerAddress a,
  Uint8List pinned,
  LinkCredentials c,
  ResumeToken? r,
) => ServerLink.connect(a, pinnedServerPub: pinned, creds: c, resume: r);

/// Сервер по адресу ещё не добавлен: что показать человеку до подключения.
class ServerProbe {
  const ServerProbe(this.address, this.info);
  final ServerAddress address;
  final ServerInfo info;

  /// Отпечаток пришёл в адресе (`#…`) и совпал — спрашивать не нужно.
  bool get pinnedByAddress => address.fingerprint != null;
}

/// Серверы в рельсе и их соединения.
class ServersController extends ChangeNotifier {
  ServersController({
    required this.db,
    required this.credentials,
    this.onReady,
    LinkDialer? dial,
    InfoFetcher? fetch,
    int Function()? nowMs,
  }) : _dial = dial ?? _linkConnect,
       _fetch = fetch ?? fetchServerInfo,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDb db;
  final LinkCredentials credentials;
  final OnReady? onReady;
  final LinkDialer _dial;
  final InfoFetcher _fetch;
  final int Function() _nowMs;

  final List<(ServerRow, ServerConnection)> _servers = [];
  int? _selectedId;
  bool _loaded = false;

  /// Список прочитан из базы.
  bool get loaded => _loaded;

  List<(ServerRow, ServerConnection)> get servers => List.unmodifiable(_servers);

  (ServerRow, ServerConnection)? get selected {
    for (final s in _servers) {
      if (s.$1.id == _selectedId) return s;
    }
    return _servers.isEmpty ? null : _servers.first;
  }

  void select(int id) {
    _selectedId = id;
    notifyListeners();
  }

  /// Читает серверы из базы и подключается ко всем.
  Future<void> load() async {
    for (final row in await db.allServers()) {
      _servers.add((row, _connection(row)..start()));
    }
    _loaded = true;
    notifyListeners();
  }

  ServerConnection _connection(ServerRow row) {
    final addr = ServerAddress(row.host, row.port);
    late final ServerConnection conn;
    conn = ServerConnection(
      address: addr,
      serverPub: row.serverPub,
      credentials: credentials,
      name: row.name,
      onReady: onReady,
      onRename: (name) => unawaited(db.renameServer(row.id, name)),
      dial: (resume) => _dial(conn.address, row.serverPub, credentials, resume),
    );
    return conn;
  }

  /// Первый шаг добавления: разобрать адрес и получить server_info. Если в
  /// адресе был отпечаток, а ключ другой — «это не тот сервер».
  Future<ServerProbe> probe(String input) async {
    final addr = ServerAddress.parse(input);
    final (info, _) = await _fetch(addr);
    if (addr.fingerprint != null && addr.fingerprint != fingerprint(info.serverPub)) {
      throw const LinkException(LinkError.wrongServer);
    }
    return ServerProbe(addr, info);
  }

  /// Второй шаг: войти с ключом из server_info. Ключ закрепляется только
  /// после удачного входа — тогда сервер появляется в рельсе.
  Future<ServerConnection> add(ServerProbe p) async {
    for (final (row, conn) in _servers) {
      if (_same(row.serverPub, p.info.serverPub)) {
        _selectedId = row.id;
        notifyListeners();
        return conn;
      }
    }
    final link = await _dial(p.address, p.info.serverPub, credentials, null);
    final ServerRow row;
    try {
      row = await db.upsertServer(
        serverPub: p.info.serverPub,
        host: p.address.host,
        port: p.address.port,
        name: link.ready?.server.name ?? p.info.name,
        nowMs: _nowMs(),
      );
    } catch (_) {
      await link.close();
      rethrow;
    }
    final conn = _connection(row);
    _servers.add((row, conn));
    _selectedId = row.id;
    notifyListeners();
    await conn.adopt(link);
    return conn;
  }

  /// Для golden-снимков и тестов: сервер без сети.
  @visibleForTesting
  void debugAdd(ServerRow row, ServerConnection conn) {
    _servers.add((row, conn));
    _loaded = true;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final (_, c) in _servers) {
      c.dispose();
    }
    super.dispose();
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
