@Tags(['live'])
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/account/account_store.dart';
import 'package:yeenlink/core/account/account_sync.dart';
import 'package:yeenlink/core/db/app_db.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/net/server_address.dart';
import 'package:yeenlink/core/net/server_link.dart';
import 'package:yeenlink/core/protocol/handshake.dart';
import 'package:yeenlink/core/protocol/messages.dart';
import 'package:yeenlink/core/servers/server_connection.dart';
import 'package:yeenlink/core/servers/servers_controller.dart';
import 'package:yeenlink/core/vault/key_vault.dart';
import 'package:yeenlink/core/vault/master_lock.dart';

import '../../helpers/live_server.dart';

/// Клиент на Dart против настоящего ylsrv: вход, admin.claim, resume, чужой
/// ключ. Без бинарника (make build-server) тест пропускается.
void main() {
  final bin = ylsrvPath();
  late LiveServer srv;
  setUpAll(() async {
    if (bin != null) srv = await LiveServer.start(bin, name: 'Ночной привал');
  });
  tearDownAll(() async {
    if (bin != null) await srv.stop();
  });

  test('вход по ключу и роль Владельца', skip: bin == null ? 'нет ylsrv' : null, () async {
    final (info, _) = await fetchServerInfo(srv.addr);
    expect(info.name, 'Ночной привал');
    expect(fingerprint(info.serverPub), srv.printedFingerprint);

    final (_, creds) = await newCredentials();
    final link = await ServerLink.connect(srv.addr, pinnedServerPub: info.serverPub, creds: creds);
    expect(link.unbound, isFalse);
    final ready = link.ready!;
    expect(ready.server.hasOwner, isFalse);
    expect(ready.me.owner, isFalse);
    expect(ready.roles.map((r) => r.builtin), containsAll(['everyone', 'owner']));

    // Неверный ключ — bad_token, соединение живо.
    await expectLater(
      link.call(Op.adminClaim, {'token': 'ylat_${'0' * 43}'}),
      throwsA(isA<ServerError>().having((e) => e.code, 'code', ErrCode.badToken)),
    );
    final update = link.events.firstWhere((f) => f.op == Op.serverUpdate);
    final claimed = await link.call(Op.adminClaim, {'token': srv.readToken()});
    expect((claimed! as Map)['owner'], isTrue);
    expect(serverUpdate(await update).hasOwner, isTrue);
    expect(File(srv.tokenPath).existsSync(), isFalse);

    // Resume после обрыва: та же сессия, без полного ready.
    final token = ResumeToken(ready.session.id, ready.lastEvent);
    await link.close();
    final back = await ServerLink.connect(
      srv.addr,
      pinnedServerPub: info.serverPub,
      creds: creds,
      resume: token,
    );
    expect(back.resumed, isNotNull);
    expect(back.resumed!.events.map((f) => f.op), contains(Op.serverUpdate));
    await back.close();

    // Новый вход — уже Владелец со всеми правами.
    final again = await ServerLink.connect(srv.addr, pinnedServerPub: info.serverPub, creds: creds);
    expect(again.ready!.me.owner, isTrue);
    expect(again.ready!.permsServer, -1);
    expect(hasPerm(again.ready!.permsServer, permOwner), isTrue);
    await again.close();
  });

  test(
    'чужой закреплённый ключ — «это не тот сервер»',
    skip: bin == null ? 'нет ylsrv' : null,
    () async {
      final (_, creds) = await newCredentials();
      final (other, _) = await newCredentials();
      await expectLater(
        ServerLink.connect(srv.addr, pinnedServerPub: other.masterPub, creds: creds),
        throwsA(isA<LinkException>().having((e) => e.error, 'error', LinkError.wrongServer)),
      );
    },
  );

  test('недоступный адрес', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    await expectLater(
      fetchServerInfo(ServerAddress('127.0.0.1', port)),
      throwsA(isA<LinkException>().having((e) => e.error, 'error', LinkError.unreachable)),
    );
  });

  test(
    'приложение без интерфейса: адрес с отпечатком → вход → профиль и устройства → Владелец',
    skip: bin == null ? 'нет ylsrv' : null,
    () async {
      final own = await LiveServer.start(bin!, name: 'Логово');
      addTearDown(own.stop);
      final dir = await Directory.systemTemp.createTemp('yl-live-app');
      addTearDown(() => dir.delete(recursive: true));
      final store = AccountStore(
        vault: MemoryVault(),
        dir: dir,
        kdfParams: const KdfParams(memoryKib: 64, iterations: 1, parallelism: 1),
      );
      final (id, _) = await newCredentials();
      var acc = await store.create(
        identity: id,
        pin: '135790',
        draft: const ProfileDraft(name: 'Пятнистый'),
        deviceName: 'ПК',
        platform: 'linux',
      );
      final creds = LinkCredentials(
        masterPub: acc.masterPub,
        devicePub: acc.devicePub,
        deviceCert: acc.deviceCert,
        deviceSeed: await store.deviceSeed(),
      );
      final sync = AccountSync(store: store, unlock: () async => null);
      final synced = Completer<void>();
      final db = AppDb(NativeDatabase.memory());
      addTearDown(db.close);
      final servers = ServersController(
        db: db,
        credentials: creds,
        onReady: (conn, ready) async {
          acc = await sync.run(acc, ready.me, conn.call);
          synced.complete();
        },
      );
      addTearDown(servers.dispose);

      // Чужой отпечаток в адресе — «это не тот сервер», в рельсу ничего не попадает.
      await expectLater(
        servers.probe('${own.addr.authority}#0000·0000·0000·0000'),
        throwsA(isA<LinkException>().having((e) => e.error, 'error', LinkError.wrongServer)),
      );
      final probe = await servers.probe('${own.addr.authority}#${own.printedFingerprint}');
      expect(probe.pinnedByAddress, isTrue);
      final conn = await servers.add(probe);
      expect(conn.state, ConnState.online);
      expect(conn.hasOwner, isFalse);
      await synced.future;
      expect((await db.allServers()).single.name, 'Логово');

      // Профиль и список устройств лежат на сервере: новый вход их отдаёт.
      final check = await ServerLink.connect(
        own.addr,
        pinnedServerPub: probe.info.serverPub,
        creds: creds,
      );
      expect((await openProfile(check.ready!.me.profile!)).name, 'Пятнистый');
      expect((await openDevices(check.ready!.me.devices!, acc.masterPub)).active, [acc.devicePub]);
      await check.close();

      await conn.claimOwner('  ${own.readToken()}\n');
      expect(conn.isOwner, isTrue);
      expect(conn.hasOwner, isTrue);
      await expectLater(
        conn.claimOwner('ylat_${'1' * 43}'),
        throwsA(isA<ServerError>().having((e) => e.code, 'code', ErrCode.badToken)),
      );
    },
  );
}
