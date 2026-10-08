import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/db/app_db.dart';

void main() {
  late AppDb db;
  setUp(() => db = AppDb(NativeDatabase.memory()));
  tearDown(() => db.close());

  Uint8List key(int b) => Uint8List(32)..fillRange(0, 32, b);

  test('серверы идут по порядку, ключ уникален, адрес обновляется', () async {
    final a = await db.upsertServer(serverPub: key(1), host: 'a', port: 443, name: 'А', nowMs: 1);
    final b = await db.upsertServer(serverPub: key(2), host: 'b', port: 8443, name: 'Б', nowMs: 2);
    expect([a.position, b.position], [0, 1]);
    final a2 = await db.upsertServer(serverPub: key(1), host: 'a2', port: 1, name: 'А2', nowMs: 3);
    expect(a2.id, a.id);
    expect((a2.host, a2.port, a2.name, a2.position, a2.addedAt), ('a2', 1, 'А2', 0, 1));
    expect((await db.allServers()).map((s) => s.name), ['А2', 'Б']);
    await db.removeServer(a.id);
    expect((await db.allServers()).map((s) => s.name), ['Б']);
  });

  test('ключ сервера — ровно 32 байта', () async {
    expect(
      () => db.upsertServer(serverPub: Uint8List(31), host: 'a', port: 1, name: 'x', nowMs: 1),
      throwsA(isA<SqliteException>()),
    );
  });
}
