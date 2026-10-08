import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/account/account_store.dart';
import 'package:yeenlink/core/account/pin_guard.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/vault/key_vault.dart';
import 'package:yeenlink/core/vault/master_lock.dart';

/// Минимальные параметры Argon2id — только для скорости тестов.
const _fastKdf = KdfParams(memoryKib: 64, iterations: 1, parallelism: 1);

const _phrase = 'virus lock response horror bread test riot control flavor poverty isolate arch';

void main() {
  late Directory dir;
  late MemoryVault vault;
  late DateTime now;
  late AccountStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('yl-account');
    vault = MemoryVault();
    now = DateTime.fromMillisecondsSinceEpoch(1790000000000);
    store = AccountStore(
      vault: vault,
      dir: dir,
      kdfParams: _fastKdf,
      nowMs: () => now.millisecondsSinceEpoch,
      guard: PinGuard(vault, now: () => now),
    );
  });
  tearDown(() => dir.delete(recursive: true));

  test('создание: профиль подписан главным ключом, ключ в хранилище только под PIN', () async {
    final id = await Identity.fromMnemonic(_phrase);
    final acc = await store.create(
      identity: id,
      pin: '135790',
      draft: const ProfileDraft(
        name: '  Пятнистый ',
        about: 'Ночные походы',
        bannerColor: 'banner-3',
      ),
      deviceName: 'Компьютер · Linux',
      platform: 'linux',
    );
    final profile = await openProfile(acc.profile!);
    expect(profile.name, 'Пятнистый');
    expect(profile.bannerColor, 'banner-3');
    expect(profile.wall, isTrue);
    expect(profile.seq, 1);
    expect(profile.nextKeyHash, id.nextKeyHash);
    expect((await openDeviceCert(acc.deviceCert, id.masterPub)).platform, 'linux');

    // Ни энтропии, ни главного ключа в хранилище открытым текстом нет.
    for (final v in vault.debugContents.values) {
      expect(_contains(v, id.entropy), isFalse);
      expect(_contains(v, id.masterSeed), isFalse);
    }

    final loaded = await store.load();
    expect(loaded!.masterPub, id.masterPub);
    expect(loaded.devicePub, acc.devicePub);

    final unlocked = await store.unlock('135790');
    expect(unlocked.mnemonic, _phrase);
  });

  test('неверный PIN: ошибка, после пяти — растущая пауза, ключ не стирается', () async {
    await store.restore(
      identity: await Identity.fromMnemonic(_phrase),
      pin: '111111',
      deviceName: 'Телефон · Pixel 8',
      platform: 'android',
    );
    for (var i = 0; i < PinGuard.freeAttempts; i++) {
      await expectLater(store.unlock('000000'), throwsA(isA<WrongSecret>()));
    }
    await expectLater(
      store.unlock('111111'),
      throwsA(isA<PinWait>().having((w) => w.left, 'left', PinGuard.firstPause)),
    );
    now = now.add(PinGuard.firstPause);
    await expectLater(store.unlock('000000'), throwsA(isA<WrongSecret>()));
    await expectLater(
      store.unlock('111111'),
      throwsA(isA<PinWait>().having((w) => w.left, 'left', PinGuard.firstPause * 2)),
    );
    now = now.add(const Duration(minutes: 1));
    expect((await store.unlock('111111')).mnemonic, _phrase);
    expect(await store.guard.wait(), isNull, reason: 'после верного PIN счётчик сброшен');
  });

  test('восстановление: только сертификат устройства, профиль придёт с сервера', () async {
    final acc = await store.restore(
      identity: await Identity.fromMnemonic(_phrase.toUpperCase()),
      pin: '222222',
      deviceName: 'Компьютер · Windows',
      platform: 'windows',
    );
    expect(acc.profile, isNull);
    expect((await store.load())!.profile, isNull);
  });

  test('wipe стирает всё (сброс профиля из настроек, фаза 7)', () async {
    await store.restore(
      identity: await Identity.fromMnemonic(_phrase),
      pin: '333333',
      deviceName: 'Компьютер · Linux',
      platform: 'linux',
    );
    await store.wipe();
    expect(await store.load(), isNull);
    expect(vault.debugContents, isEmpty);
  });

  test('блоб: AAD привязан к главному ключу, параметры KDF читаются из блоба', () async {
    final id = await Identity.fromMnemonic(_phrase);
    final blob = await MasterLock.seal(
      entropy: id.entropy,
      secret: '424242',
      kind: SecretKind.pin,
      masterPub: id.masterPub,
      params: _fastKdf,
    );
    expect(
      await MasterLock.open(blob: blob, secret: '424242', masterPub: id.masterPub),
      id.entropy,
    );
    expect(MasterLock.kindOf(blob), SecretKind.pin);
    await expectLater(
      MasterLock.open(blob: blob, secret: '424242', masterPub: Uint8List(32)),
      throwsA(isA<WrongSecret>()),
    );
    final tampered = Uint8List.fromList(blob)..[7] ^= 1; // memory_kib
    await expectLater(
      MasterLock.open(blob: tampered, secret: '424242', masterPub: id.masterPub),
      throwsA(isA<WrongSecret>()),
    );
  });

  test('выбор параметров KDF по замеру', () async {
    Future<void> fast(KdfParams _) async {}
    Future<void> slow(KdfParams _) => Future.delayed(const Duration(milliseconds: 400));
    expect(await KdfParams.choose(probe: fast), KdfParams.standard);
    expect(await KdfParams.choose(probe: slow), KdfParams.light);
  });
}

bool _contains(List<int> hay, List<int> needle) {
  for (var i = 0; i + needle.length <= hay.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length && ok; j++) {
      ok = hay[i + j] == needle[j];
    }
    if (ok) return true;
  }
  return false;
}
