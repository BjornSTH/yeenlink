import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../codec/codec.dart';
import '../net/server_address.dart';
import '../net/server_link.dart';
import '../protocol/handshake.dart';
import '../protocol/messages.dart';

/// Состояние связи с сервером.
enum ConnState {
  /// Первое подключение или переподключение.
  connecting,

  /// Вошли, работаем.
  online,

  /// Обрыв; повтор по таймеру.
  retrying,

  /// Остановились: повтор не поможет (чужой ключ, подмена сертификата,
  /// устройство отозвано, другая версия). Повтор — только вручную.
  failed,
}

/// Ошибки, после которых автоматический повтор бессмыслен или опасен.
const _fatal = {
  LinkError.wrongServer,
  LinkError.certNotSigned,
  LinkError.deviceRevoked,
  LinkError.proto,
  LinkError.replaced,
};

/// Что делать после входа: сверить профиль и устройства (AccountSync).
typedef OnReady = Future<void> Function(ServerConnection conn, Ready ready);

/// Подключение к одному серверу: вход, переподключение с resume, события.
///
/// Задержка повтора — 1, 2, 4… до 30 с с разбросом ±30% (docs/spec.md,
/// «Переключение адресов»); запасные адреса — в фазе 4.
class ServerConnection extends ChangeNotifier {
  ServerConnection({
    required this.address,
    required this.serverPub,
    required this.credentials,
    required this._name,
    this.onReady,
    this.onRename,
    this._dial,
    Random? random,
  }) : _random = random ?? Random();

  ServerAddress address;
  final Uint8List serverPub;
  final LinkCredentials credentials;
  final OnReady? onReady;

  /// Сервер сменил название — сохранить для рельсы.
  final void Function(String name)? onRename;

  final Future<ServerLink> Function(ResumeToken? resume)? _dial;
  final Random _random;

  ConnState _state = ConnState.connecting;
  ConnState get state => _state;

  LinkError? _error;

  /// Почему нет связи (для retrying и failed).
  LinkError? get error => _error;

  String _name;
  String get name => _name;

  bool _hasOwner = true;
  bool get hasOwner => _hasOwner;

  bool _isOwner = false;
  bool get isOwner => _isOwner;

  bool _unbound = false;

  /// Сервер за прокси не знает свой сертификат — подмена не исключена.
  bool get unbound => _unbound;

  int _permsServer = 0;
  int get permsServer => _permsServer;

  ServerLink? _link;
  ResumeToken? _resume;
  int _attempt = 0;
  Timer? _timer;
  bool _disposed = false;

  /// Когда будет следующая попытка (для retrying).
  DateTime? retryAt;

  void start() {
    if (_link != null || _disposed || _state == ConnState.online) return;
    unawaited(_connect());
  }

  /// «Повторить сейчас» — и после фатальной ошибки тоже.
  void retryNow() {
    _timer?.cancel();
    _attempt = 0;
    unawaited(_connect());
  }

  Future<ServerLink> _open(ResumeToken? resume) =>
      _dial?.call(resume) ??
      ServerLink.connect(address, pinnedServerPub: serverPub, creds: credentials, resume: resume);

  Future<void> _connect() async {
    if (_state != ConnState.retrying) _set(ConnState.connecting);
    final ServerLink link;
    try {
      link = await _open(_resume);
    } on LinkException catch (e) {
      _resume = null;
      _fail(e);
      return;
    }
    await _attach(link);
  }

  /// Принимает соединение, уже открытое при добавлении сервера.
  Future<void> adopt(ServerLink link) => _attach(link);

  Future<void> _attach(ServerLink link) async {
    if (_disposed) {
      await link.close();
      return;
    }
    _timer?.cancel();
    _link = link;
    _attempt = 0;
    _error = null;
    _unbound = link.unbound;
    final ready = link.ready;
    if (ready != null) {
      _resume = ResumeToken(ready.session.id, ready.lastEvent);
      _applyServer(ready.server);
      _isOwner = ready.me.owner;
      _permsServer = ready.permsServer;
    } else {
      final r = link.resumed!;
      _resume = ResumeToken(r.session.id, r.lastEvent);
      r.events.forEach(_onEvent);
    }
    _set(ConnState.online);
    link.events.listen(_onEvent);
    unawaited(
      link.done.then((why) {
        if (_link != link) return;
        _link = null;
        if (!_disposed) _fail(why);
      }),
    );
    if (ready != null && onReady != null) {
      try {
        await onReady!(this, ready);
      } on Object catch (e) {
        debugPrint('сверка профиля с сервером: $e');
      }
    }
  }

  void _fail(LinkException e) {
    _error = e.error;
    if (_fatal.contains(e.error)) {
      _set(ConnState.failed);
      return;
    }
    final base = min(30, 1 << min(_attempt, 5));
    _attempt++;
    final jitter = 1 + (_random.nextDouble() * 0.6 - 0.3);
    final delay = Duration(milliseconds: (base * 1000 * jitter).round());
    retryAt = DateTime.now().add(delay);
    _set(ConnState.retrying);
    _timer = Timer(delay, () => unawaited(_connect()));
  }

  void _onEvent(Frame f) {
    // Номер события сервер не присылает в кадре; resume с last_event из
    // ready/resumed отдаст всё после него — дубли безвредны: события
    // фазы 2 задают состояние целиком.
    try {
      switch (f.op) {
        case Op.serverUpdate:
          _applyServer(serverUpdate(f));
        case Op.memberUpdate:
          final m = MemberUpdate.decode(f);
          if (_same(m.masterPub, credentials.masterPub)) {
            _isOwner = m.owner;
            // В фазе 2 права есть только у Владельца; с фазы 3 — perms.update.
            _permsServer = m.owner ? -1 : 0;
          }
      }
    } on CodecException catch (e) {
      debugPrint('событие ${f.op} не разобрано: $e');
    }
    notifyListeners();
  }

  void _applyServer(ServerState s) {
    _hasOwner = s.hasOwner;
    if (s.name != _name) {
      _name = s.name;
      onRename?.call(s.name);
    }
  }

  /// Для тестов интерфейса: ответы на запросы без сервера.
  @visibleForTesting
  Future<Object?> Function(String op, Object? data)? debugCall;

  /// Запрос к серверу; без связи — [LinkException].
  Future<Object?> call(String op, Object? data) {
    final fake = debugCall;
    if (fake != null) return fake(op, data);
    final link = _link;
    if (link == null || !link.isOpen) {
      return Future.error(LinkException(_error ?? LinkError.closed));
    }
    return link.call(op, data);
  }

  /// Ключ администратора: роль Владельца — этому главному ключу.
  Future<void> claimOwner(String token) async {
    await call(Op.adminClaim, {'token': token.trim()});
    _isOwner = true;
    _hasOwner = true;
    _permsServer = -1;
    notifyListeners();
  }

  /// Для golden-снимков и тестов интерфейса: состояние без сервера.
  @visibleForTesting
  void debugSet({
    ConnState? state,
    LinkError? error,
    bool? hasOwner,
    bool? isOwner,
    bool? unbound,
  }) {
    _state = state ?? _state;
    _error = error ?? _error;
    _hasOwner = hasOwner ?? _hasOwner;
    _isOwner = isOwner ?? _isOwner;
    _unbound = unbound ?? _unbound;
    notifyListeners();
  }

  void _set(ConnState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_link?.close());
    _link = null;
    super.dispose();
  }

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
