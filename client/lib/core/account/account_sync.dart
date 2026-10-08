import 'dart:async';
import 'dart:typed_data';

import '../identity/identity.dart';
import '../net/server_link.dart';
import '../protocol/handshake.dart';
import '../protocol/messages.dart';
import 'account_store.dart';

/// Главный ключ, оставшийся в памяти после создания или восстановления
/// профиля в этом запуске приложения. Нужен один раз — подписать список
/// устройств, — после чего забывается.
class MasterKeyCache {
  Identity? _identity;

  void keep(Identity identity) {
    _identity?.wipe();
    _identity = identity;
  }

  /// Отдаёт ключ и забывает его; затирает ключ вызывающий.
  Identity? take() {
    final i = _identity;
    _identity = null;
    return i;
  }

  void clear() => take()?.wipe();
}

/// Запрос к серверу после входа ([ServerLink.call]).
typedef ServerCall = Future<Object?> Function(String op, Object? data);

/// Сверяет профиль и список устройств с сервером после ready
/// (spec/auth.md, «Профиль и устройства»): берёт более новую версию по seq,
/// недостающую отправляет. Если этого устройства нет в списке — подписывает
/// следующий список главным ключом: из [MasterKeyCache] или по PIN ([unlock]).
class AccountSync {
  AccountSync({required this.store, required this.unlock});

  final AccountStore store;

  /// Главный ключ по PIN; null — человек отказался (спросим при следующем входе).
  final Future<Identity?> Function() unlock;

  // Серверы подключаются параллельно, а PIN нужен один раз: сверки — по очереди.
  Future<void> _queue = Future.value();

  Future<LocalAccount> run(LocalAccount account, Me me, ServerCall call) {
    final done = Completer<LocalAccount>();
    _queue = _queue.then((_) async {
      try {
        // Аккаунт мог обновиться предыдущей сверкой.
        final fresh = await store.load() ?? account;
        var acc = await _profile(fresh, me, call);
        acc = await _devices(acc, me, call);
        done.complete(acc);
      } on Object catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<LocalAccount> _profile(LocalAccount acc, Me me, ServerCall call) async {
    final local = acc.profile == null ? null : await openProfile(acc.profile!);
    Profile? remote;
    if (me.profile != null) {
      try {
        remote = await openProfile(me.profile!);
        if (!_same(remote.master, acc.masterPub)) remote = null;
      } on Exception {
        remote = null;
      }
    }
    if (remote != null && (local == null || remote.seq > local.seq)) {
      return store.adoptProfile(acc, me.profile!);
    }
    if (local != null && (remote == null || local.seq > remote.seq)) {
      await _push(call, Op.profilePush, {'profile': acc.profile!.encode()});
    }
    return acc;
  }

  Future<LocalAccount> _devices(LocalAccount acc, Me me, ServerCall call) async {
    final local = acc.devices == null ? null : await openDevices(acc.devices!, acc.masterPub);
    Devices? remote;
    if (me.devices != null) {
      try {
        remote = await openDevices(me.devices!, acc.masterPub);
      } on Exception {
        remote = null;
      }
    }
    final useRemote = remote != null && (local == null || remote.seq > local.seq);
    final best = useRemote ? remote : local;
    final bestSigned = useRemote ? me.devices : acc.devices;
    if (best != null && best.active.any((k) => _same(k, acc.devicePub))) {
      if (useRemote) acc = await store.saveDevices(acc, bestSigned!);
      if (remote == null || remote.seq < best.seq) {
        await _push(call, Op.devicesPush, {'devices': bestSigned!.encode()});
      }
      return acc;
    }
    // Устройство отозвано — сервер и так не пустит; новый список не подписываем.
    if (best != null && best.revoked.any((k) => _same(k, acc.devicePub))) return acc;

    final identity = await unlock();
    if (identity == null) return acc;
    final Signed signed;
    try {
      signed = await store.signDevices(
        identity,
        Devices(
          seq: (best?.seq ?? 0) + 1,
          active: [...?best?.active, acc.devicePub],
          revoked: [...?best?.revoked],
        ),
      );
    } finally {
      identity.wipe();
    }
    acc = await store.saveDevices(acc, signed);
    await _push(call, Op.devicesPush, {'devices': signed.encode()});
    return acc;
  }

  /// stale — на сервере уже новее (другое устройство успело раньше): не ошибка.
  static Future<void> _push(ServerCall call, String op, Object data) async {
    try {
      await call(op, data);
    } on ServerError catch (e) {
      if (e.code != ErrCode.stale) rethrow;
    }
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
