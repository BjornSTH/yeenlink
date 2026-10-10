import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/account/account_store.dart';
import 'package:yeenlink/core/account/account_sync.dart';
import 'package:yeenlink/core/db/app_db.dart';
import 'package:yeenlink/core/identity/identity.dart';
import 'package:yeenlink/core/net/server_address.dart';
import 'package:yeenlink/core/net/server_link.dart';
import 'package:yeenlink/core/protocol/handshake.dart';
import 'package:yeenlink/core/servers/server_connection.dart';
import 'package:yeenlink/core/servers/servers_controller.dart';
import 'package:yeenlink/core/vault/key_vault.dart';
import 'package:yeenlink/core/vault/master_lock.dart';
import 'package:yeenlink/features/home/home_controller.dart';
import 'package:yeenlink/features/home/home_screen.dart';

import '../helpers/app.dart';

const _phrase = 'virus lock response horror bread test riot control flavor poverty isolate arch';
const _pc = Size(1440, 900);
const _phone = Size(390, 844);

/// Главное окно фазы 2 без сети: серверы — заготовки с состоянием.
class _Home {
  _Home(this.store, this.account, this.creds, this.serverInfo);

  final AccountStore store;
  final LocalAccount account;
  final LinkCredentials creds;
  final (ServerInfo, Signed) serverInfo;

  late HomeController home;
  late ServersController servers;
  final calls = <String>[];

  /// [fetch] и [dial] — что вернёт «сеть» при добавлении сервера.
  Widget build({
    List<(String name, ConnState state, bool hasOwner, LinkError? error)> list = const [],
    Future<Object?> Function(String op, Object? data)? call,
    InfoFetcher? fetch,
  }) {
    calls.clear();
    final db = AppDb(NativeDatabase.memory());
    addTearDown(db.close);
    servers = ServersController(
      db: db,
      credentials: creds,
      fetch: fetch ?? (_) async => serverInfo,
      dial: (_, _, _, _) async => throw const LinkException(LinkError.unreachable),
    );
    for (final (i, (name, state, hasOwner, error)) in list.indexed) {
      final conn = ServerConnection(
        address: const ServerAddress('nightcamp.ru', 443),
        serverPub: Uint8List(32)..[0] = i,
        credentials: creds,
        name: name,
      )..debugSet(state: state, hasOwner: hasOwner, error: error);
      conn.debugCall = (op, data) {
        calls.add(op);
        return call?.call(op, data) ?? Future.value({'owner': true});
      };
      servers.debugAdd(
        ServerRow(
          id: i + 1,
          serverPub: conn.serverPub,
          host: 'nightcamp.ru',
          port: 443,
          name: name,
          position: i,
          addedAt: 0,
        ),
        conn,
      );
    }
    servers.debugLoaded();
    home = HomeController(store: store, account: account, db: db, masterCache: MasterKeyCache())
      ..debugStart(servers);
    addTearDown(home.dispose);
    return HomeScreen(controller: home);
  }
}

void main() {
  late Directory dir;
  late _Home h;

  setUpAll(() async {
    await loadAppFonts();
    dir = await Directory.systemTemp.createTemp('yl-home');
    final store = AccountStore(
      vault: MemoryVault(),
      dir: dir,
      kdfParams: const KdfParams(memoryKib: 64, iterations: 1, parallelism: 1),
    );
    final id = await Identity.fromMnemonic(_phrase);
    final account = await store.create(
      identity: await Identity.fromMnemonic(_phrase),
      pin: '135790',
      draft: const ProfileDraft(name: 'Пятнистый'),
      deviceName: 'ПК',
      platform: 'linux',
    );
    final creds = LinkCredentials(
      masterPub: account.masterPub,
      devicePub: account.devicePub,
      deviceCert: account.deviceCert,
      deviceSeed: await store.deviceSeed(),
    );
    // server_info сервера «Логово»: ключ сервера — главный ключ из фразы.
    final info = ServerInfo(serverPub: id.masterPub, name: 'Логово', version: 'dev');
    final signed = await Signed.sign(SignedType.serverInfo, info.toMap(), id.masterSeed);
    h = _Home(store, account, creds, (info, signed));
  });
  tearDownAll(() => dir.delete(recursive: true));

  Future<void> show(WidgetTester tester, Size size, Widget w) async {
    setSurface(tester, size);
    await tester.pumpWidget(testApp(w));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  // Весь навигатор: модальные окна лежат поверх экрана, а не внутри него.
  Future<void> golden(String name) =>
      expectLater(find.byType(Navigator).first, matchesGoldenFile('goldens/home_$name.png'));

  group('golden', () {
    final noOwner = [('Ночной привал', ConnState.online, false, null)];
    final cases = <String, (Size, Future<void> Function(WidgetTester))>{
      'pc_empty': (_pc, (t) => show(t, _pc, h.build())),
      'phone_empty': (_phone, (t) => show(t, _phone, h.build())),
      'pc_no_owner': (_pc, (t) => show(t, _pc, h.build(list: noOwner))),
      'pc_claim': (
        _pc,
        (t) async {
          await show(t, _pc, h.build(list: noOwner));
          await tap(t, 'Ввести ключ администратора');
        },
      ),
      'pc_claim_done': (
        _pc,
        (t) async {
          await show(t, _pc, h.build(list: noOwner));
          await tap(t, 'Ввести ключ администратора');
          await t.enterText(find.byType(EditableText), 'ylat_${'7' * 43}');
          await tap(t, 'Стать владельцем');
        },
      ),
      'phone_no_owner': (_phone, (t) => show(t, _phone, h.build(list: noOwner))),
      'phone_claim': (
        _phone,
        (t) async {
          await show(t, _phone, h.build(list: noOwner));
          await tap(t, 'Ввести ключ администратора');
        },
      ),
      'pc_add_confirm': (
        _pc,
        (t) async {
          await show(t, _pc, h.build());
          await tap(t, 'Вставить приглашение');
          await t.enterText(find.byType(EditableText), 'chat.example.org:8443');
          await tap(t, 'Продолжить');
        },
      ),
      'pc_owner_retrying': (
        _pc,
        (t) => show(
          t,
          _pc,
          h.build(list: [('Ночной привал', ConnState.retrying, true, LinkError.closed)]),
        ),
      ),
      'pc_cert_not_signed': (
        _pc,
        (t) => show(
          t,
          _pc,
          h.build(list: [('Ночной привал', ConnState.failed, true, LinkError.certNotSigned)]),
        ),
      ),
    };
    for (final MapEntry(key: name, value: (_, go)) in cases.entries) {
      testWidgets(
        name,
        (tester) async {
          await go(tester);
          await golden(name);
        },
        tags: ['golden'],
        skip: !Platform.isLinux,
      );
    }
  });

  testWidgets('ключ администратора: формат, отказ сервера, успех', (tester) async {
    var answer = const ServerError(ErrCode.badToken, '');
    await show(
      tester,
      _pc,
      h.build(
        list: [('Ночной привал', ConnState.online, false, null)],
        call: (op, data) async {
          if (answer.code.isNotEmpty) throw answer;
          return {'owner': true};
        },
      ),
    );
    expect(find.text('У сервера пока нет владельца'), findsOneWidget);
    await tap(tester, 'Ввести ключ администратора');
    expect(find.text('Стать владельцем сервера'), findsOneWidget);
    expect(find.textContaining('У сервера «Ночной привал» пока нет владельца'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'не ключ');
    await tap(tester, 'Стать владельцем');
    expect(find.textContaining('Ключ начинается с ylat_'), findsOneWidget);
    expect(h.calls, isEmpty, reason: 'неверный формат на сервер не уходит');

    await tester.enterText(find.byType(EditableText), ' ylat_${'7' * 43}\n');
    await tap(tester, 'Стать владельцем');
    expect(find.textContaining('Ключ не подошёл'), findsOneWidget);

    answer = const ServerError(ErrCode.rateLimited, '');
    await tap(tester, 'Стать владельцем');
    expect(find.textContaining('Слишком много попыток'), findsOneWidget);

    answer = const ServerError('', '');
    await tap(tester, 'Стать владельцем');
    expect(find.textContaining('Готово. Теперь вы Владелец'), findsOneWidget);
    await tap(tester, 'Перейти к серверу');
    expect(find.text('ВЛАДЕЛЕЦ — 1'), findsOneWidget);
    expect(find.text('У сервера пока нет владельца'), findsNothing);
    expect(h.calls, [Op.adminClaim, Op.adminClaim, Op.adminClaim]);
  });

  testWidgets('добавление: полный отпечаток, чужой ключ в адресе, сервер не пустил', (
    tester,
  ) async {
    await show(tester, _pc, h.build());
    expect(find.text('Здесь пока тихо'), findsOneWidget);
    await tap(tester, 'Вставить приглашение');
    final fp = fingerprint(h.serverInfo.$1.serverPub);

    await tester.enterText(find.byType(EditableText), 'http://chat.example.org');
    await tap(tester, 'Продолжить');
    expect(find.textContaining('без схемы или с https://'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'chat.example.org#0000·0000·0000·0000');
    await tap(tester, 'Продолжить');
    expect(find.textContaining('Это не тот сервер'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'chat.example.org:8443');
    await tap(tester, 'Продолжить');
    expect(find.text(fp), findsOneWidget, reason: 'все четыре группы');
    expect(find.textContaining('Сервер «Логово»'), findsOneWidget);
    await tap(tester, 'Подключиться');
    expect(find.textContaining('Сервер не отвечает'), findsOneWidget);
    expect(h.servers.servers, isEmpty, reason: 'ключ закрепляется только после входа');

    // Отпечаток в адресе совпал — без шага сверки сразу вход.
    await tester.enterText(find.byType(EditableText), 'chat.example.org#$fp');
    await tap(tester, 'Продолжить');
    expect(find.text(fp), findsNothing);
    expect(find.textContaining('Сервер не отвечает'), findsOneWidget);
  });

  testWidgets('телефон: вкладки и «Каталог пока не работает»', (tester) async {
    await show(tester, _phone, h.build());
    await tap(tester, 'Найти в каталоге');
    expect(find.textContaining('Каталог пока не работает'), findsOneWidget);
    await tap(tester, 'Понятно');
    await tap(tester, 'Лента');
    expect(find.text('Ленты пока нет'), findsOneWidget);
    await tap(tester, 'Профиль');
    expect(find.text('Пятнистый'), findsOneWidget);
    expect(find.text(fingerprint(h.account.masterPub)), findsOneWidget);
  });
}
