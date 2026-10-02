import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/account/account_store.dart';
import 'package:yeenlink/core/account/pin_guard.dart';
import 'package:yeenlink/core/account/platform_bridge.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/vault/key_vault.dart';
import 'package:yeenlink/core/vault/master_lock.dart';
import 'package:yeenlink/features/onboarding/onboarding_controller.dart';
import 'package:yeenlink/features/onboarding/onboarding_screen.dart';

import '../helpers/app.dart';

const _phrase = 'virus lock response horror bread test riot control flavor poverty isolate arch';

class FakeBridge extends PlatformBridge {
  FakeBridge(this.os, {this.model});

  final String os;
  final String? model;
  final copied = <String>[];
  final saved = <String, String>{};

  @override
  String get platform => os;

  @override
  Future<String?> phoneModel() async => model;

  @override
  Future<void> copySensitive(String text) async => copied.add(text);

  @override
  Future<void> clearSensitiveClipboard() async => copied.clear();

  @override
  Future<bool> saveText(String fileName, String text) async {
    saved[fileName] = text;
    return true;
  }
}

class Harness {
  Harness(this.dir, {String os = 'linux', String? model})
    : bridge = FakeBridge(os, model: model),
      vault = MemoryVault() {
    store = AccountStore(
      vault: vault,
      dir: dir,
      kdfParams: const KdfParams(memoryKib: 64, iterations: 1, parallelism: 1),
      guard: PinGuard(vault),
    );
    controller = OnboardingController(
      store: store,
      pickImage: () async => null,
      newIdentity: () => Identity.fromMnemonic(_phrase),
    );
  }

  final Directory dir;
  final FakeBridge bridge;
  final MemoryVault vault;
  late final AccountStore store;
  late final OnboardingController controller;
  var opened = false;

  Widget get widget =>
      OnboardingScreen(controller: controller, bridge: bridge, onOpenApp: () => opened = true);
}

/// Ждёт асинхронную работу: Argon2id идёт в изолятах (нужно реальное время),
/// а PBKDF2 в пакете cryptography делает паузы через Future.delayed (нужно
/// время теста). Поэтому двигаем оба.
Future<void> settle(WidgetTester tester, bool Function() busy) async {
  for (var i = 0; i < 1000 && busy(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(busy(), isFalse, reason: 'асинхронная работа не завершилась');
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String label, String text) async {
  final field = find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
    matching: find.byType(EditableText),
  );
  await tester.enterText(field.first, text);
  await tester.pump();
}

void main() {
  late Directory dir;
  setUpAll(loadAppFonts);
  setUp(() async => dir = await Directory.systemTemp.createTemp('yl-onb'));
  tearDown(() => dir.delete(recursive: true));

  testWidgets('создание: имя → фраза → PIN → подключение → готово', (tester) async {
    setSurface(tester, const Size(1440, 900));
    final h = Harness(dir);
    await tester.pumpWidget(testApp(h.widget));

    await tester.tap(find.text('Создать профиль'));
    await tester.pump();
    expect(find.text('Шаг 1 из 4'), findsOneWidget);
    expect(
      find.text('Введите имя'),
      findsOneWidget,
      reason: 'без имени «Дальше» объясняет, чего нет',
    );

    await enter(tester, 'Имя', '  Пятнистый ');
    await enter(tester, 'О себе (необязательно)', 'Ночные походы');
    await tester.tap(find.bySemanticsLabel('Цвет баннера 3'));
    await tester.tap(find.text('Дальше'));
    await settle(tester, () => h.controller.identity == null);

    expect(find.text('Шаг 2 из 4'), findsOneWidget);
    for (final w in _phrase.split(' ')) {
      expect(find.text(w), findsOneWidget);
    }
    await tester.tap(find.text('Скопировать'));
    await tester.pump();
    expect(h.bridge.copied.single, _phrase);

    await tester.tap(find.text('Сохранить в файл'));
    await tester.pump();
    expect(find.textContaining('синхронизируются с облаком'), findsOneWidget);
    await tester.tap(find.text('Выбрать, куда сохранить'));
    await tester.pump();
    final file = h.bridge.saved['yeenlink-recovery.txt']!;
    expect(file, contains('1. virus'));
    expect(file, contains('12. arch'));

    // Без галочки дальше нельзя.
    await tester.tap(find.text('Дальше'));
    await tester.pump();
    expect(find.text('Шаг 2 из 4'), findsOneWidget);
    await tester.tap(find.text('Я записал фразу в надёжном месте'));
    await tester.pump();
    await tester.tap(find.text('Дальше'));
    await tester.pumpAndSettle();

    expect(find.text('Шаг 3 из 4'), findsOneWidget);
    await enter(tester, 'PIN-код', '13579x0');
    await enter(tester, 'Повторите PIN-код', '135791');
    expect(find.text('PIN-коды не совпадают.'), findsOneWidget);
    expect(h.controller.pin, '135790', reason: 'только цифры');
    await enter(tester, 'Повторите PIN-код', '135790');
    await tester.tap(find.text('Дальше'));
    await settle(tester, () => h.controller.step == OnbStep.pin && h.controller.saveError == null);

    expect(find.text('Шаг 4 из 4'), findsOneWidget);
    await tester.tap(find.text('Подключиться'));
    await tester.pump();
    expect(find.textContaining('появится в фазе 2'), findsOneWidget);
    await tester.tap(find.text('Пропустить пока'));
    await tester.pump();

    expect(find.text('Профиль готов'), findsOneWidget);
    await tester.tap(find.text('Открыть YeenLink'));
    expect(h.opened, isTrue);

    final acc = await tester.runAsync(h.store.load);
    final profile = await tester.runAsync(() => openProfile(acc!.profile!));
    expect(profile!.name, 'Пятнистый');
    expect(profile.about, 'Ночные походы');
    expect(profile.bannerColor, 'banner-3');
    final cert = DeviceCert.fromMap(acc!.deviceCert.payloadMap());
    expect(cert.name, 'Компьютер · Linux');
    expect(cert.platform, 'linux');
    expect(h.controller.identity, isNull, reason: 'главный ключ стёрт из памяти');
  });

  testWidgets('восстановление: ошибки фразы, PIN, готово; QR — заглушка', (tester) async {
    setSurface(tester, const Size(390, 844));
    final h = Harness(dir, os: 'android', model: 'Pixel 8');
    await tester.pumpWidget(testApp(h.widget));

    await tester.tap(find.text('У меня уже есть профиль'));
    await tester.pump();
    expect(find.text('Восстановить профиль'), findsOneWidget);

    await tester.tap(find.text('QR с другого устройства'));
    await tester.pump();
    expect(find.textContaining('появится в фазе 7'), findsOneWidget);
    await tester.tap(find.text('Секретная фраза'));
    await tester.pump();

    final cases = {
      'virus lock response': 'Нужно 12 слов — сейчас 3.',
      _phrase.replaceFirst('horror', 'hyena'): 'Слово 4 «hyena» не из списка. Проверьте написание.',
      _phrase.replaceFirst('arch', 'about'):
          'Все слова из списка, но фраза не сходится. Проверьте порядок слов и опечатки.',
    };
    for (final MapEntry(key: input, value: message) in cases.entries) {
      await enter(tester, '12 слов через пробел', input);
      await tester.tap(find.text('Восстановить'));
      await settle(tester, () => h.controller.checkingPhrase);
      expect(find.text(message), findsOneWidget, reason: input);
    }

    await enter(tester, '12 слов через пробел', '  ${_phrase.toUpperCase()}  ');
    await tester.tap(find.text('Восстановить'));
    await settle(tester, () => h.controller.checkingPhrase);
    expect(find.text('Придумайте PIN-код'), findsOneWidget);
    expect(find.textContaining('Шаг'), findsNothing, reason: 'у восстановления нет полосы шагов');

    await enter(tester, 'PIN-код', '246802');
    await enter(tester, 'Повторите PIN-код', '246802');
    await tester.tap(find.text('Дальше'));
    await settle(tester, () => h.controller.step == OnbStep.pin && h.controller.saveError == null);

    expect(find.text('Профиль готов'), findsOneWidget);
    expect(find.textContaining('подтянутся с сервера'), findsOneWidget);
    final acc = await tester.runAsync(h.store.load);
    expect(acc!.profile, isNull);
    expect(DeviceCert.fromMap(acc.deviceCert.payloadMap()).name, 'Телефон · Pixel 8');
    expect(
      find.text('Начать заново'),
      findsNothing,
      reason: 'сброс — в настройках, с подтверждением',
    );
  });

  group('golden: шаги онбординга', () {
    const screens = {'pc': Size(1440, 900), 'phone': Size(390, 844)};
    final steps = <String, Future<void> Function(WidgetTester, Harness)>{
      'welcome': (t, h) async {},
      'profile': (t, h) async => h.controller.startCreate(),
      'seed': (t, h) async {
        h.controller
          ..startCreate()
          ..update((c) => c.name = 'Пятнистый');
        await t.runAsync(h.controller.toSeed);
      },
      'pin': (t, h) async {
        h.controller
          ..startCreate()
          ..update((c) => c.name = 'Пятнистый');
        await t.runAsync(h.controller.toSeed);
        h.controller
          ..update((c) => c.seedConfirmed = true)
          ..toPin();
      },
      'join': (t, h) async {
        h.controller
          ..startCreate()
          ..update((c) => c.name = 'Пятнистый');
        await t.runAsync(h.controller.toSeed);
        h.controller
          ..update((c) => c.seedConfirmed = true)
          ..toPin()
          ..update((c) => c.pin = c.pinRepeat = '135790');
        await t.runAsync(
          () => h.controller.savePin(deviceName: 'Компьютер · Linux', platform: 'linux'),
        );
      },
      'restore': (t, h) async => h.controller.startRestore(),
      'done': (t, h) async {
        h.controller
          ..startCreate()
          ..update((c) => c.name = 'Пятнистый');
        await t.runAsync(h.controller.toSeed);
        h.controller
          ..update((c) => c.seedConfirmed = true)
          ..toPin()
          ..update((c) => c.pin = c.pinRepeat = '135790');
        await t.runAsync(
          () => h.controller.savePin(deviceName: 'Компьютер · Linux', platform: 'linux'),
        );
        h.controller.skipJoin();
      },
    };
    for (final MapEntry(key: screen, value: size) in screens.entries) {
      for (final MapEntry(key: step, value: go) in steps.entries) {
        testWidgets(
          '$screen $step',
          (tester) async {
            setSurface(tester, size);
            final h = Harness(dir);
            await go(tester, h);
            await tester.pumpWidget(
              testApp(RepaintBoundary(key: const ValueKey('s'), child: h.widget)),
            );
            await tester.pumpAndSettle();
            await expectLater(
              find.byKey(const ValueKey('s')),
              matchesGoldenFile('goldens/onboarding_${screen}_$step.png'),
            );
          },
          tags: ['golden'],
          skip: !Platform.isLinux,
        );
      }
    }
  });

  test('аватар в профиль не попадает, пока не выбран; черновик проверяется', () {
    final h = Harness(Directory.systemTemp);
    expect(h.controller.draftError, DraftError.nameEmpty);
    h.controller.update((c) => c.name = 'Я' * 33);
    expect(h.controller.draftError, DraftError.nameTooLong);
    h.controller.update((c) => c.name = 'Пят\u0007нистый');
    expect(h.controller.draftError, DraftError.nameControl);
    h.controller.update((c) => c.name = '\u202Eйытсинтяп');
    expect(h.controller.draftError, DraftError.nameBidi);
    h.controller.update((c) => c.name = 'Пятнистый👨\u200D👩\u200D👧');
    expect(h.controller.draftError, isNull, reason: 'ZWJ в эмодзи разрешён');
    h.controller.update((c) => c.about = 'ночью \u2067tset\u2069');
    expect(h.controller.draftError, DraftError.aboutBidi);
    h.controller.update(
      (c) => c
        ..name = 'Пятнистый'
        ..about = '',
    );
    expect(h.controller.draftError, isNull);
    expect(h.controller.avatar, isNull);
    expect(Uint8List(0), isEmpty);
  });
}
