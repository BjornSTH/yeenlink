// Проверка на настоящей платформе (Windows, Linux, Android):
//   flutter test integration_test -d <устройство>
//
// Критерий фазы 1: «подпись с одной платформы проверяется на другой» —
// конверт подписан на Go, проверяется здесь, а подпись, сделанная здесь,
// байт в байт совпадает с подписью Go. Плюс настоящее системное хранилище.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yeenlink/core/account/account_store.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/vault/key_vault.dart';
import 'package:yeenlink/core/vault/master_lock.dart';

import 'reference.dart';

Uint8List _hex(String s) => Uint8List.fromList([
  for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
]);

String _toHex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ключи из фразы совпадают с Go', (tester) async {
    final id = await Identity.fromMnemonic(refMnemonic);
    expect(_toHex(id.masterPub), refMasterPub);
    expect(fingerprint(id.masterPub), refFingerprint);
    expect(_toHex(id.nextKeyHash), refNextKeyHash);
  });

  testWidgets('подпись Go проверяется здесь, подпись здесь совпадает с Go', (tester) async {
    final fromGo = Signed.decode(_hex(refProfileSigned));
    final profile = await openProfile(fromGo);
    expect(_toHex(profile.master), refMasterPub);

    final id = await Identity.fromMnemonic(refMnemonic);
    final here = await Signed.signBytes(SignedType.profile, fromGo.p, id.masterSeed);
    expect(_toHex(here.s), refProfileSignature);
    expect(here.encode(), fromGo.encode());
  });

  testWidgets('системное хранилище: запись, чтение, профиль под PIN', (tester) async {
    final vault = SecureVault();
    const key = 'yl.integration-test';
    await vault.write(key, Uint8List.fromList([1, 2, 3]));
    expect(await vault.read(key), [1, 2, 3]);
    await vault.delete(key);
    expect(await vault.read(key), isNull);

    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/integration-test');
    final sw = Stopwatch()..start();
    final params = await KdfParams.choose();
    // ignore: avoid_print
    print(
      'KDF на ${Platform.operatingSystem}: ${params.memoryKib} КиБ, t=${params.iterations}, '
      'выбор ${sw.elapsedMilliseconds} мс',
    );

    final store = AccountStore(vault: vault, dir: dir, kdfParams: params);
    try {
      final id = await Identity.fromMnemonic(refMnemonic);
      await store.restore(identity: id, pin: '135790', deviceName: 'Тест', platform: _platform());
      sw.reset();
      final unlocked = await store.unlock('135790');
      // ignore: avoid_print
      print('Разблокировка PIN: ${sw.elapsedMilliseconds} мс');
      expect(unlocked.mnemonic, refMnemonic);
      await expectLater(store.unlock('000000'), throwsA(isA<WrongSecret>()));
    } finally {
      await store.wipe();
    }
    expect(await store.load(), isNull);
  });
}

String _platform() => Platform.isAndroid
    ? 'android'
    : Platform.isWindows
    ? 'windows'
    : Platform.isMacOS
    ? 'macos'
    : 'linux';
