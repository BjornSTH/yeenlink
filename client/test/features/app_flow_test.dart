import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/app/app.dart';
import 'package:yeenlink/core/account/account_store.dart';
import 'package:yeenlink/core/account/pin_guard.dart';
import 'package:yeenlink/core/db/app_db.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/vault/key_vault.dart';
import 'package:yeenlink/core/vault/master_lock.dart';
import 'package:yeenlink/features/home/home_screen.dart';

import '../helpers/app.dart';
import 'onboarding_test.dart' show FakeBridge, enter;

const _phrase = 'virus lock response horror bread test riot control flavor poverty isolate arch';

/// Медленное хранилище — как Keystore на настоящем телефоне.
class SlowVault extends MemoryVault {
  static const delay = Duration(milliseconds: 300);

  @override
  Future<void> write(String key, Uint8List value) async {
    await Future<void>.delayed(delay);
    return super.write(key, value);
  }
}

/// Ждёт в реальном времени (изоляты Argon2id, медленное хранилище) и в
/// времени теста (паузы PBKDF2) — до [found] или падает с понятной ошибкой.
Future<void> waitFor(WidgetTester tester, Finder found, {int seconds = 60}) async {
  final until = DateTime.now().add(Duration(seconds: seconds));
  while (found.evaluate().isEmpty) {
    if (DateTime.now().isAfter(until)) fail('за $seconds с не появилось: $found');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Весь путь через AppRoot — от приветствия до главного окна — с настоящим
/// Argon2id (запасные параметры, в изоляте) и медленным хранилищем. Ловит
/// зависания async и переходов, которые не видны тестам отдельных шагов.
void main() {
  late Directory dir;
  setUpAll(loadAppFonts);
  setUp(() async => dir = await Directory.systemTemp.createTemp('yl-flow'));
  tearDown(() => dir.delete(recursive: true));

  Future<(AccountStore, FakeBridge)> start(WidgetTester tester) async {
    // Самый узкий экран (эмулятор в CI) и крупный системный шрифт, как часто
    // на телефонах: переполнение строк падает тестом.
    setSurface(tester, const Size(320, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final vault = SlowVault();
    final store = AccountStore(
      vault: vault,
      dir: dir,
      kdfParams: KdfParams.light,
      guard: PinGuard(vault),
    );
    final bridge = FakeBridge('android', model: 'Pixel 8');
    final services = AppServices(
      store: store,
      bridge: bridge,
      pickImage: () async => null,
      openDb: () => AppDb(NativeDatabase.memory()),
    );
    await tester.pumpWidget(testApp(AppRoot(services: services)));
    await waitFor(tester, find.text('У меня уже есть профиль'));
    return (store, bridge);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pump();
    await tester.tap(find.text(text));
  }

  Future<void> restoreToNameStep(WidgetTester tester) async {
    await tap(tester, 'У меня уже есть профиль');
    await tester.pump();
    await enter(tester, '12 слов через пробел', _phrase);
    await tap(tester, 'Восстановить');
    await tester.pump();
    await waitFor(tester, find.text('Придумайте PIN-код'));
    await enter(tester, 'PIN-код', '135790');
    await enter(tester, 'Повторите PIN-код', '135790');
    await tap(tester, 'Дальше');
    await tester.pump();
    expect(find.text('Восстанавливаю…'), findsOneWidget, reason: 'на время сохранения');
    // Второе нажатие во время сохранения ничего не ломает.
    await tap(tester, 'Восстанавливаю…');
    await waitFor(tester, find.text('Как вас называть?'));
  }

  testWidgets('восстановление без имени → главное окно: буквы отпечатка, цвет по ключу', (
    tester,
  ) async {
    final (store, _) = await start(tester);
    await restoreToNameStep(tester);
    await tap(tester, 'Пропустить пока');
    await waitFor(tester, find.text('Профиль готов'));
    await tap(tester, 'Открыть YeenLink');
    await waitFor(tester, find.byType(HomeScreen));
    await waitFor(tester, find.text('Здесь пока тихо'));
    await tap(tester, 'Профиль');
    await tester.pump();

    final id = await tester.runAsync(() => Identity.fromMnemonic(_phrase));
    final fp = fingerprint(id!.masterPub);
    expect(find.text(fp), findsOneWidget);
    expect(find.text('Имя не указано'), findsOneWidget);
    expect(find.text(fp.substring(0, 2)), findsOneWidget, reason: 'буквы — из отпечатка');
    expect(find.text('ПВ'), findsNothing);
    expect((await tester.runAsync(store.load))!.profile, isNull);
  });

  testWidgets('восстановление с именем → профиль seq 0 → главное окно', (tester) async {
    final (store, _) = await start(tester);
    await restoreToNameStep(tester);
    await enter(tester, 'Имя', 'Gnoll');
    await tap(tester, 'Дальше');
    await waitFor(tester, find.text('Профиль готов'));
    await tap(tester, 'Открыть YeenLink');
    await waitFor(tester, find.byType(HomeScreen));
    await waitFor(tester, find.text('Здесь пока тихо'));
    await tap(tester, 'Профиль');
    await tester.pump();

    expect(find.text('Gnoll'), findsOneWidget);
    expect(find.text('GN'), findsOneWidget);
    final acc = await tester.runAsync(store.load);
    final profile = await tester.runAsync(() => openProfile(acc!.profile!));
    expect(profile!.seq, 0, reason: 'любой профиль с сервера заменит локальный');
    expect(profile.name, 'Gnoll');
  });
}
