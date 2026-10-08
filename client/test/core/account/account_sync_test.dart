import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/account/account_store.dart';
import 'package:yeenlink/core/account/account_sync.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/net/server_link.dart';
import 'package:yeenlink/core/protocol/handshake.dart';
import 'package:yeenlink/core/protocol/messages.dart';
import 'package:yeenlink/core/vault/key_vault.dart';
import 'package:yeenlink/core/vault/master_lock.dart';

const _fastKdf = KdfParams(memoryKib: 64, iterations: 1, parallelism: 1);
const _phrase = 'virus lock response horror bread test riot control flavor poverty isolate arch';

/// Сервер в памяти: хранит профиль и список устройств по правилам seq.
class _FakeServer {
  Signed? profile;
  Signed? devices;
  final pushes = <String>[];

  Me me(Uint8List master) => Me.fromMap({
    'master_pub': master,
    'owner': false,
    'profile': ?profile?.encode(),
    'devices': ?devices?.encode(),
  });

  Future<Object?> call(String op, Object? data) async {
    pushes.add(op);
    final d = data! as Map<String, Object?>;
    switch (op) {
      case Op.profilePush:
        final s = Signed.decode(d['profile']! as Uint8List);
        final seq = (await openProfile(s)).seq;
        if (profile != null && seq <= (await openProfile(profile!)).seq) {
          throw const ServerError(ErrCode.stale, '');
        }
        profile = s;
        return {'seq': seq};
      case Op.devicesPush:
        final s = Signed.decode(d['devices']! as Uint8List);
        final seq = (await openDevices(s, s.k)).seq;
        if (devices != null && seq <= (await openDevices(devices!, devices!.k)).seq) {
          throw const ServerError(ErrCode.stale, '');
        }
        devices = s;
        return {'seq': seq};
    }
    throw ServerError(ErrCode.unknownOp, op);
  }
}

void main() {
  late Directory dir;
  late AccountStore store;
  late _FakeServer server;
  var pinAsked = 0;
  Identity? pinAnswer;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yl-sync');
    store = AccountStore(vault: MemoryVault(), dir: dir, kdfParams: _fastKdf);
    server = _FakeServer();
    pinAsked = 0;
    pinAnswer = null;
  });
  tearDown(() => dir.delete(recursive: true));

  AccountSync sync([MasterKeyCache? cache]) => AccountSync(
    store: store,
    unlock: () async {
      final cached = cache?.take();
      if (cached != null) return cached;
      pinAsked++;
      return pinAnswer;
    },
  );

  Future<Devices> serverDevices() => openDevices(server.devices!, server.devices!.k);

  test('новый профиль: профиль и список устройств уходят на сервер без PIN', () async {
    final id = await Identity.fromMnemonic(_phrase);
    final acc = await store.create(
      identity: id,
      pin: '135790',
      draft: const ProfileDraft(name: 'Пятнистый'),
      deviceName: 'ПК',
      platform: 'linux',
    );
    await sync().run(acc, server.me(acc.masterPub), server.call);
    expect(server.pushes, [Op.profilePush, Op.devicesPush]);
    expect((await serverDevices()).active, [acc.devicePub]);
    expect(pinAsked, 0);

    // Второй вход: всё совпадает — ничего не отправляется.
    server.pushes.clear();
    await sync().run(acc, server.me(acc.masterPub), server.call);
    expect(server.pushes, isEmpty);
  });

  test('восстановление: профиль берётся с сервера, устройство добавляется по PIN', () async {
    // Первое устройство.
    final id = await Identity.fromMnemonic(_phrase);
    final first = await store.create(
      identity: id,
      pin: '135790',
      draft: const ProfileDraft(name: 'Пятнистый'),
      deviceName: 'ПК',
      platform: 'linux',
    );
    await sync().run(first, server.me(first.masterPub), server.call);

    // Второе — восстановлено по фразе, профиль seq 0 с другим именем.
    final restored = await store.restore(
      identity: await Identity.fromMnemonic(_phrase),
      pin: '246801',
      deviceName: 'Телефон',
      platform: 'android',
    );
    final withName = await store.saveRestoredProfile(
      identity: await Identity.fromMnemonic(_phrase),
      draft: const ProfileDraft(name: 'Не то имя'),
    );
    server.pushes.clear();
    pinAnswer = await Identity.fromMnemonic(_phrase);
    final acc = await sync().run(withName, server.me(restored.masterPub), server.call);

    expect(
      (await openProfile(acc.profile!)).name,
      'Пятнистый',
      reason: 'seq 1 с сервера заменил seq 0',
    );
    expect(pinAsked, 1);
    final list = await serverDevices();
    expect(list.seq, 2);
    expect(list.active, [first.devicePub, restored.devicePub]);
    expect(server.pushes, [Op.devicesPush]);
    expect(pinAnswer!.masterSeed.every((b) => b == 0), isTrue, reason: 'ключ затёрт после подписи');
  });

  test('ключ в памяти после восстановления — PIN не спрашивается; отказ — без списка', () async {
    final id = await Identity.fromMnemonic(_phrase);
    final acc = await store.restore(
      identity: id,
      pin: '246801',
      deviceName: 'ПК',
      platform: 'linux',
    );

    // Отказ от PIN: список не подписан, вход не сломан.
    var after = await sync().run(acc, server.me(acc.masterPub), server.call);
    expect(pinAsked, 1);
    expect(server.devices, isNull);
    expect(after.devices, isNull);

    final cache = MasterKeyCache()..keep(await Identity.fromMnemonic(_phrase));
    after = await sync(cache).run(acc, server.me(acc.masterPub), server.call);
    expect(pinAsked, 1);
    expect((await serverDevices()).active, [acc.devicePub]);
    expect(cache.take(), isNull, reason: 'ключ забыт после подписи');
    expect((await store.load())!.devices, isNotNull);
  });

  test(
    'на сервере список новее и с этим устройством — сохраняется локально, без отправки',
    () async {
      final id = await Identity.fromMnemonic(_phrase);
      final acc = await store.create(
        identity: id,
        pin: '135790',
        draft: const ProfileDraft(name: 'Пятнистый'),
        deviceName: 'ПК',
        platform: 'linux',
      );
      final other = Uint8List(32)..[0] = 7;
      server.devices = await store.signDevices(
        await Identity.fromMnemonic(_phrase),
        Devices(seq: 5, active: [acc.devicePub, other], revoked: const []),
      );
      server.profile = acc.profile;
      final after = await sync().run(acc, server.me(acc.masterPub), server.call);
      expect(server.pushes, isEmpty);
      expect((await openDevices(after.devices!, acc.masterPub)).seq, 5);
    },
  );
}
