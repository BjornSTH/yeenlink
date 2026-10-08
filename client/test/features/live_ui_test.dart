@Tags(['live'])
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/app/app.dart';
import 'package:yeenlink/core/account/account_store.dart';
import 'package:yeenlink/core/db/app_db.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/net/server_link.dart';
import 'package:yeenlink/core/vault/key_vault.dart';
import 'package:yeenlink/core/vault/master_lock.dart';

import '../helpers/app.dart';
import '../helpers/live_server.dart';
import 'onboarding_test.dart' show FakeBridge;

/// Критерий фазы 2 через интерфейс: чистый ylsrv → «Добавить сервер» по
/// адресу с отпечатком из `ylsrv init` → окно ключа администратора открылось
/// само → ключ → «Готово» → в списке участников «ВЛАДЕЛЕЦ — 1». Сеть
/// настоящая; без бинарника (make build-server) тест пропускается.
void main() {
  final bin = ylsrvPath();

  testWidgets('вход по ключу и роль Владельца — через интерфейс', skip: bin == null, (
    tester,
  ) async {
    // flutter_test подменяет HttpClient заглушкой — здесь нужна сеть.
    HttpOverrides.global = null;
    final srv = (await tester.runAsync(() => LiveServer.start(bin!, name: 'Логово')))!;
    addTearDown(() => tester.runAsync(srv.stop));
    final dir = (await tester.runAsync(() => Directory.systemTemp.createTemp('yl-live-ui')))!;
    addTearDown(() => tester.runAsync(() => dir.delete(recursive: true)));
    final store = AccountStore(
      vault: MemoryVault(),
      dir: dir,
      kdfParams: const KdfParams(memoryKib: 64, iterations: 1, parallelism: 1),
    );
    final account = (await tester.runAsync(
      () async => store.create(
        identity: (await newCredentials()).$1,
        pin: '135790',
        draft: const ProfileDraft(name: 'Пятнистый'),
        deviceName: 'ПК',
        platform: 'linux',
      ),
    ))!;

    await loadAppFonts();
    setSurface(tester, const Size(1440, 900));
    await tester.pumpWidget(
      YeenLinkApp(
        services: AppServices(
          store: store,
          bridge: FakeBridge('linux'),
          pickImage: () async => null,
          openDb: () => AppDb(NativeDatabase.memory()),
        ),
      ),
    );

    Future<void> waitFor(Finder f, {int seconds = 30}) async {
      final until = DateTime.now().add(Duration(seconds: seconds));
      while (f.evaluate().isEmpty) {
        if (DateTime.now().isAfter(until)) {
          fail('за $seconds с не появилось: $f\nжурнал ylsrv:\n${srv.log}');
        }
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump(const Duration(milliseconds: 20));
      }
    }

    Future<void> tap(String text) async {
      await tester.tap(find.text(text).last);
      await tester.pump();
    }

    await waitFor(find.text('Здесь пока тихо'));
    await tap('Вставить приглашение');
    await waitFor(find.text('Адрес сервера'));
    await tester.enterText(
      find.byType(EditableText),
      '${srv.addr.authority}#${srv.printedFingerprint}',
    );
    await tap('Продолжить');

    // Отпечаток совпал — без сверки сразу вход; сервер без владельца — окно ключа.
    await waitFor(find.text('Стать владельцем сервера'));
    expect(find.textContaining('У «Логово» пока нет владельца'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), srv.readToken());
    await tap('Стать владельцем');
    await waitFor(find.textContaining('Готово. Теперь вы Владелец «Логово»'));
    await tap('Перейти к серверу');
    await waitFor(find.text('ВЛАДЕЛЕЦ — 1'));
    expect(find.text('У сервера пока нет владельца'), findsNothing);
    expect(File(srv.tokenPath).existsSync(), isFalse, reason: 'ключ сгорел');

    // Сервер помнит: роль, профиль и список устройств — у нового входа.
    final check = (await tester.runAsync(() async {
      final (info, _) = await fetchServerInfo(srv.addr);
      final link = await ServerLink.connect(
        srv.addr,
        pinnedServerPub: info.serverPub,
        creds: LinkCredentials(
          masterPub: account.masterPub,
          devicePub: account.devicePub,
          deviceCert: account.deviceCert,
          deviceSeed: await store.deviceSeed(),
        ),
      );
      final me = link.ready!.me;
      final out = (
        me.owner,
        (await openProfile(me.profile!)).name,
        (await openDevices(me.devices!, account.masterPub)).active.length,
      );
      await link.close();
      return out;
    }))!;
    expect(check, (true, 'Пятнистый', 1));

    // Закрыть приложение: соединения и база.
    // Таймеры dart:io (ожидание кадра закрытия) живут во времени теста — прокручиваем.
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(seconds: 6));
  });
}
