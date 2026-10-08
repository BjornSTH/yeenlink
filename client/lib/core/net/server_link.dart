import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../codec/codec.dart';
import '../identity/identity.dart';
import '../protocol/handshake.dart';
import '../protocol/messages.dart';
import 'server_address.dart';

/// Ключи этого устройства для входа.
class LinkCredentials {
  const LinkCredentials({
    required this.masterPub,
    required this.devicePub,
    required this.deviceCert,
    required this.deviceSeed,
  });

  final Uint8List masterPub;
  final Uint8List devicePub;
  final Signed deviceCert;
  final Uint8List deviceSeed;
}

/// Сессия для resume после обрыва.
class ResumeToken {
  const ResumeToken(this.session, this.lastEvent);
  final Uint8List session;
  final int lastEvent;
}

/// Почему не удалось войти или соединение закрылось.
enum LinkError {
  /// Сервер не ответил, TLS или HTTP не сложились.
  unreachable,

  /// Ответ не похож на сервер YeenLink.
  notYeenLink,

  /// Ключ сервера не тот, что закреплён.
  wrongServer,

  /// Сертификат TLS не подписан ключом сервера — возможна подмена.
  certNotSigned,

  /// Устройство отвязано от профиля.
  deviceRevoked,

  /// Другая версия протокола.
  proto,

  /// Сервер отказал во входе (подпись, сертификат устройства, сроки).
  rejected,

  /// Соединение оборвалось.
  closed,

  /// Сессию продолжили в другом соединении.
  replaced,
}

class LinkException implements Exception {
  const LinkException(this.error, [this.detail = '']);
  final LinkError error;
  final String detail;

  @override
  String toString() => 'LinkException(${error.name}${detail.isEmpty ? '' : ': $detail'})';
}

/// Ошибка ответа на запрос (`e` в кадре).
class ServerError implements Exception {
  const ServerError(this.code, this.msg);
  final String code;
  final String msg;

  @override
  String toString() => 'ServerError($code: $msg)';
}

/// Сколько ждать ответа сервера на шаге входа или на запрос.
const linkTimeout = Duration(seconds: 15);

/// Клиент TLS, который принимает любой сертификат и запоминает DER того,
/// что пришёл. Доверие держится на ключе сервера: подпись challenge
/// покрывает хеш этого сертификата (spec/auth.md).
class _PinningClient {
  _PinningClient() {
    http
      ..connectionTimeout = linkTimeout
      ..idleTimeout = Duration.zero
      ..connectionFactory = (uri, proxyHost, proxyPort) async {
        final task = await SecureSocket.startConnect(
          uri.host,
          uri.port,
          onBadCertificate: (_) => true,
          supportedProtocols: const ['http/1.1'],
        );
        return ConnectionTask.fromSocket(
          task.socket.then((s) {
            seenDer = s.peerCertificate?.der;
            return s;
          }),
          task.cancel,
        );
      };
  }

  final HttpClient http = HttpClient();
  Uint8List? seenDer;

  void close() => http.close(force: true);
}

/// server_info с адреса — до входа, чтобы показать название и отпечаток.
Future<(ServerInfo, Signed)> fetchServerInfo(ServerAddress addr) async {
  final client = _PinningClient();
  try {
    final req = await client.http
        .getUrl(addr.baseUri.replace(path: '/.well-known/yeenlink'))
        .timeout(linkTimeout);
    final resp = await req.close().timeout(linkTimeout);
    if (resp.statusCode != HttpStatus.ok) {
      await resp.drain<void>();
      throw LinkException(LinkError.notYeenLink, 'HTTP ${resp.statusCode}');
    }
    final body = BytesBuilder(copy: false);
    await for (final chunk in resp.timeout(linkTimeout)) {
      body.add(chunk);
      if (body.length > 64 * 1024) throw const LinkException(LinkError.notYeenLink, 'велик');
    }
    try {
      final signed = Signed.decode(body.takeBytes());
      return (await openServerInfo(signed), signed);
    } on Exception catch (e) {
      throw LinkException(LinkError.notYeenLink, '$e');
    }
  } on LinkException {
    rethrow;
  } on Exception catch (e) {
    throw LinkException(LinkError.unreachable, '$e');
  } finally {
    client.close();
  }
}

/// Соединение с сервером после входа: запросы по id и события.
class ServerLink {
  ServerLink._(this._ws, this.wire);

  final WebSocket _ws;
  final Wire wire;

  /// Сервер не знает свой сертификат: защиты от подмены нет.
  bool unbound = false;

  /// Ответ на вход: ready (полный) или resumed (после обрыва).
  Ready? ready;
  Resumed? resumed;

  final _pending = <int, Completer<Frame>>{};
  // Не broadcast: события сразу после ready копятся, пока не подпишутся.
  final _events = StreamController<Frame>();
  final _done = Completer<LinkException>();
  var _nextId = 0;

  /// События сервера (кадры без id); слушатель — один.
  Stream<Frame> get events => _events.stream;

  /// Чем закончилось соединение.
  Future<LinkException> get done => _done.future;

  bool get isOpen => !_done.isCompleted;

  /// Подключается и входит. [pinnedServerPub] — закреплённый ключ сервера.
  static Future<ServerLink> connect(
    ServerAddress addr, {
    required Uint8List pinnedServerPub,
    required LinkCredentials creds,
    ResumeToken? resume,
    Wire wire = Wire.cbor,
  }) async {
    final client = _PinningClient();
    final WebSocket ws;
    try {
      ws = await WebSocket.connect(
        addr.baseUri.replace(scheme: 'wss', path: '/ws').toString(),
        customClient: client.http,
      ).timeout(linkTimeout);
    } on Exception catch (e) {
      client.close();
      throw LinkException(LinkError.unreachable, '$e');
    }
    final seen = client.seenDer;
    ws.pingInterval = const Duration(seconds: 30);
    final link = ServerLink._(ws, wire).._listen();
    try {
      await link._login(addr, pinnedServerPub, creds, resume, seen == null ? null : certHash(seen));
      return link;
    } catch (_) {
      await link.close();
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> _login(
    ServerAddress addr,
    Uint8List pinned,
    LinkCredentials creds,
    ResumeToken? resume,
    Uint8List? seenHash,
  ) async {
    final rnd = Random.secure();
    final clientNonce = Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
    final Frame chFrame;
    try {
      chFrame = await _request(
        Op.hello,
        helloPayload(
          masterPub: creds.masterPub,
          devicePub: creds.devicePub,
          deviceCert: creds.deviceCert.encode(),
          clientNonce: clientNonce,
          resume: resume == null ? null : (session: resume.session, lastEvent: resume.lastEvent),
        ),
      );
    } on ServerError catch (e) {
      throw _loginError(e);
    }
    final Challenge ch;
    try {
      ch = Challenge.fromMap(chFrame.decodeD()! as Map<String, Object?>);
    } on Object catch (e) {
      throw LinkException(LinkError.notYeenLink, '$e');
    }
    try {
      unbound = await verifyChallenge(
        ch,
        pinnedServerPub: pinned,
        clientNonce: clientNonce,
        seenCertHash: seenHash,
      );
    } on ChallengeException catch (e) {
      throw LinkException(switch (e.error) {
        ChallengeError.wrongServer => LinkError.wrongServer,
        ChallengeError.certNotSigned => LinkError.certNotSigned,
      });
    }
    final sig = await signAuth(creds.deviceSeed, ch.nonce, pinned, ch.ts);
    final Frame answer;
    try {
      answer = await _request(Op.auth, {'sig': sig});
    } on ServerError catch (e) {
      throw _loginError(e);
    }
    try {
      switch (answer.op) {
        case Op.ready:
          ready = Ready.decode(answer);
          if (!_same(ready!.server.pub, pinned)) throw const LinkException(LinkError.wrongServer);
        case Op.resumed:
          resumed = Resumed.decode(answer);
        default:
          throw LinkException(LinkError.notYeenLink, 'после auth пришёл ${answer.op}');
      }
    } on LinkException {
      rethrow;
    } on Object catch (e) {
      throw LinkException(LinkError.notYeenLink, '$e');
    }
  }

  static LinkException _loginError(ServerError e) => LinkException(switch (e.code) {
    ErrCode.deviceRevoked => LinkError.deviceRevoked,
    ErrCode.proto => LinkError.proto,
    _ => LinkError.rejected,
  }, '${e.code}: ${e.msg}');

  void _listen() {
    _ws.listen(
      (msg) {
        if (_done.isCompleted) return;
        final Frame f;
        try {
          final bytes = msg is String ? utf8.encode(msg) : msg as List<int>;
          f = wire.decodeFrame(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
        } on Object catch (e) {
          _finish(LinkException(LinkError.notYeenLink, '$e'));
          return;
        }
        final id = f.id;
        if (id != null) {
          _pending.remove(id)?.complete(f);
        } else if (f.op == 'error' && f.e != null) {
          _finish(_closeError(f.e!));
        } else {
          _events.add(f);
        }
      },
      onDone: () => _finish(LinkException(LinkError.closed, '${_ws.closeCode ?? ''}')),
      onError: (Object e) => _finish(LinkException(LinkError.closed, '$e')),
      cancelOnError: true,
    );
  }

  static LinkException _closeError(FrameError e) => LinkException(switch (e.code) {
    ErrCode.deviceRevoked => LinkError.deviceRevoked,
    ErrCode.replaced => LinkError.replaced,
    ErrCode.proto => LinkError.proto,
    _ => LinkError.rejected,
  }, '${e.code}: ${e.msg}');

  void _finish(LinkException why) {
    if (_done.isCompleted) return;
    _done.complete(why);
    for (final p in _pending.values) {
      p.completeError(why);
    }
    _pending.clear();
    unawaited(_events.close());
    unawaited(_ws.close());
  }

  Future<Frame> _request(String op, Object? data) async {
    if (!isOpen) throw await done;
    final id = ++_nextId;
    final c = Completer<Frame>();
    _pending[id] = c;
    _ws.add(wire.encodeFrame(Frame(op, id: id, data: data)));
    final f = await c.future.timeout(
      linkTimeout,
      onTimeout: () {
        _pending.remove(id);
        throw LinkException(LinkError.closed, '$op: нет ответа');
      },
    );
    final e = f.e;
    if (e != null) throw ServerError(e.code, e.msg);
    return f;
  }

  /// Запрос после входа; ответ — разобранное `d` (или null без него).
  Future<Object?> call(String op, Object? data) async {
    final f = await _request(op, data);
    return f.d == null ? null : f.decodeD();
  }

  Future<void> close() async {
    _finish(const LinkException(LinkError.closed, 'закрыто клиентом'));
  }

  static bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
