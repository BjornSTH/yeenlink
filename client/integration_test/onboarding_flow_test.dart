// Полный путь восстановления через настоящее приложение на платформе:
// системное хранилище, канал yeenlink/platform, реальное время.
//   flutter test integration_test/onboarding_flow_test.dart -d <устройство>
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yeenlink/app/app.dart';
import 'package:yeenlink/core/account/account_store.dart';
import 'package:yeenlink/core/account/platform_bridge.dart';
import 'package:yeenlink/core/db/app_db.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/vault/key_vault.dart';

import 'reference.dart';

final _clock = Stopwatch()..start();

void _log(String what) {
  // ignore: avoid_print
  print('[${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(1)} с] $what');
}

/// Ждёт виджет в реальном времени, перерисовывая кадры. Падает с понятной
/// ошибкой, если за [timeout] он так и не появился.
Future<void> waitFor(
  WidgetTester tester,
  Finder f, {
  Duration timeout = const Duration(seconds: 90),
}) async {
  final until = DateTime.now().add(timeout);
  while (f.evaluate().isEmpty) {
    if (DateTime.now().isAfter(until)) {
      fail('за ${timeout.inSeconds} с не появилось: $f');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Нажимает кнопку, сначала прокрутив к ней: на маленьком экране эмулятора
/// длинный шаг не помещается целиком.
Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await tester.pump();
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
    matching: find.byType(EditableText),
  );
  await tester.ensureVisible(field.first);
  await tester.enterText(field.first, text);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('восстановление по фразе → PIN → имя (пропуск) → «Готово» → главное окно', (
    tester,
  ) async {
    final support = await getApplicationSupportDirectory();
    final store = AccountStore(vault: SecureVault(), dir: Directory('${support.path}/flow-test'));
    await store.wipe();
    addTearDown(store.wipe);
    final services = AppServices(
      store: store,
      bridge: PlatformBridge(),
      pickImage: () async => null,
      // В памяти, но тем же SQLite из сборки — проверка, что библиотека есть на платформе.
      openDb: () => AppDb(NativeDatabase.memory()),
    );

    await tester.pumpWidget(YeenLinkApp(services: services));
    await waitFor(tester, find.text('У меня уже есть профиль'));
    _log('приветствие');

    await tapText(tester, 'У меня уже есть профиль');
    await enter(tester, '12 слов через пробел', refMnemonic);
    await tapText(tester, 'Восстановить');
    _log('нажато «Восстановить»');
    await waitFor(tester, find.text('Придумайте PIN-код'));
    _log('шаг PIN');

    await enter(tester, 'PIN-код', '135790');
    await enter(tester, 'Повторите PIN-код', '135790');
    await tapText(tester, 'Дальше');
    _log('нажато «Дальше» на PIN');
    await waitFor(tester, find.text('Как вас называть?'));
    _log('шаг имени после восстановления');
    await tapText(tester, 'Пропустить пока');
    await waitFor(tester, find.text('Профиль готов'));
    _log('экран «Готово»');

    await tapText(tester, 'Открыть YeenLink');
    await waitFor(tester, find.text('Здесь пока тихо'));
    _log('главное окно без серверов');
    // На телефоне профиль — во вкладке «Профиль»; на ПК без серверов его не видно.
    if (find.text('Профиль').evaluate().isNotEmpty) {
      await tapText(tester, 'Профиль');
      await waitFor(tester, find.text(refFingerprint));
      expect(find.text(refFingerprint.substring(0, 2)), findsOneWidget, reason: 'буквы аватара');
    }
    _log('отпечаток ${fingerprint(await _masterPub(store))}');
  });
}

Future<List<int>> _masterPub(AccountStore store) async => (await store.load())!.masterPub;
