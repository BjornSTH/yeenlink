import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_db.g.dart';

/// Серверы, к которым подключался человек. Ключ сервера закрепляется при
/// первом удачном входе (spec/auth.md, «Первый контакт и отпечаток»).
@DataClassName('ServerRow')
class Servers extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Ключ сервера Ed25519 — личность сервера; адрес может меняться.
  BlobColumn get serverPub => blob().unique().check(serverPub.length.equals(32))();

  /// Адрес, по которому подключались последний раз.
  TextColumn get host => text()();
  IntColumn get port => integer()();

  /// Название из server_info — для рельсы, пока нет связи.
  TextColumn get name => text()();

  /// Порядок в рельсе.
  IntColumn get position => integer()();

  /// unix-время в мс.
  IntColumn get addedAt => integer()();
}

/// Локальная база клиента (drift, SQLite). Файл — в папке приложения.
@DriftDatabase(tables: [Servers])
class AppDb extends _$AppDb {
  AppDb(super.e);

  /// База в папке приложения (drift_flutter выбирает путь под платформу).
  factory AppDb.open() => AppDb(driftDatabase(name: 'yeenlink'));

  @override
  int get schemaVersion => 1;

  Stream<List<ServerRow>> watchServers() =>
      (select(servers)..orderBy([(s) => OrderingTerm(expression: s.position)])).watch();

  Future<List<ServerRow>> allServers() =>
      (select(servers)..orderBy([(s) => OrderingTerm(expression: s.position)])).get();

  Future<ServerRow?> serverByPub(Uint8List pub) =>
      (select(servers)..where((s) => s.serverPub.equals(pub))).getSingleOrNull();

  /// Добавляет сервер в конец рельсы или обновляет адрес и название, если
  /// ключ уже известен.
  Future<ServerRow> upsertServer({
    required Uint8List serverPub,
    required String host,
    required int port,
    required String name,
    required int nowMs,
  }) => transaction(() async {
    final existing = await serverByPub(serverPub);
    if (existing != null) {
      await (update(servers)..where((s) => s.id.equals(existing.id))).write(
        ServersCompanion(host: Value(host), port: Value(port), name: Value(name)),
      );
      return (await serverByPub(serverPub))!;
    }
    final last = await (selectOnly(servers)..addColumns([servers.position.max()])).getSingle();
    final position = (last.read(servers.position.max()) ?? -1) + 1;
    await into(servers).insert(
      ServersCompanion.insert(
        serverPub: serverPub,
        host: host,
        port: port,
        name: name,
        position: position,
        addedAt: nowMs,
      ),
    );
    return (await serverByPub(serverPub))!;
  });

  Future<void> renameServer(int id, String name) =>
      (update(servers)..where((s) => s.id.equals(id))).write(ServersCompanion(name: Value(name)));

  Future<void> removeServer(int id) => (delete(servers)..where((s) => s.id.equals(id))).go();
}
