import 'package:flutter/foundation.dart';

import '../../core/account/account_store.dart';
import '../../core/account/account_sync.dart';
import '../../core/db/app_db.dart';
import '../../core/identity/identity.dart';
import '../../core/net/server_link.dart';
import '../../core/servers/servers_controller.dart';

/// Главное окно без виджетов: профиль этого устройства, серверы и сверка
/// профиля с ними. Виджеты только показывают состояние и зовут методы.
class HomeController extends ChangeNotifier {
  HomeController({
    required this.store,
    required LocalAccount account,
    required this.db,
    required this.masterCache,
    this.dial,
    this.fetch,
  }) : account = ValueNotifier(account);

  final AccountStore store;
  final AppDb db;
  final MasterKeyCache masterCache;
  final LinkDialer? dial;
  final InfoFetcher? fetch;

  /// Профиль на этом устройстве; обновляется после сверки с сервером.
  final ValueNotifier<LocalAccount> account;

  ServersController? _servers;
  ServersController get servers => _servers!;
  bool get started => _servers != null;

  /// PIN-код от человека — главный ключ, чтобы подписать список устройств.
  /// Ставит экран; null — экрана нет или человек отказался.
  Future<Identity?> Function()? askPin;

  late final AccountSync _sync = AccountSync(
    store: store,
    unlock: () async => masterCache.take() ?? await askPin?.call(),
  );

  /// Ключ устройства из хранилища и серверы из базы.
  Future<void> start() async {
    if (_servers != null) return;
    final acc = account.value;
    final creds = LinkCredentials(
      masterPub: acc.masterPub,
      devicePub: acc.devicePub,
      deviceCert: acc.deviceCert,
      deviceSeed: await store.deviceSeed(),
    );
    _servers = ServersController(
      db: db,
      credentials: creds,
      dial: dial,
      fetch: fetch,
      onReady: (conn, ready) async {
        account.value = await _sync.run(account.value, ready.me, conn.call);
      },
    );
    notifyListeners();
    await _servers!.load();
  }

  /// Для golden-снимков: серверы без сети.
  @visibleForTesting
  void debugStart(ServersController servers) {
    _servers = servers;
    notifyListeners();
  }

  @override
  void dispose() {
    _servers?.dispose();
    account.dispose();
    masterCache.clear();
    super.dispose();
  }
}
