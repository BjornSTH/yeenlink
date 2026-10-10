import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

import '../identity/keys.dart';

/// Вход на сервер (spec/auth.md) — те же байты, что в server/pkg/protocol.

/// Версия протокола в hello.
const int protoVersion = 1;

/// Операции и коды ошибок фазы 2.
abstract final class Op {
  static const hello = 'hello';
  static const challenge = 'challenge';
  static const auth = 'auth';
  static const ready = 'ready';
  static const resumed = 'resumed';
  static const adminClaim = 'admin.claim';
  static const profilePush = 'profile.push';
  static const devicesPush = 'devices.push';
  static const serverUpdate = 'server.update';
  static const memberUpdate = 'member.update';
}

abstract final class ErrCode {
  static const proto = 'proto';
  static const badFrame = 'bad_frame';
  static const badCert = 'bad_cert';
  static const deviceRevoked = 'device_revoked';
  static const badSig = 'bad_sig';
  static const challengeExpired = 'challenge_expired';
  static const notAuthenticated = 'not_authenticated';
  static const rateLimited = 'rate_limited';
  static const badToken = 'bad_token';
  static const stale = 'stale';
  static const badPayload = 'bad_payload';
  static const unknownOp = 'unknown_op';
  static const replaced = 'replaced';
}

const int challengeTtlMs = 30000;

final Uint8List zeroCertHash = Uint8List(32);

Uint8List certHash(List<int> der) => Uint8List.fromList(hash.sha256.convert(der).bytes);

Uint8List _be64(int v) => (ByteData(8)..setUint64(0, v)).buffer.asUint8List();

Uint8List _cat(List<List<int>> parts) {
  final b = BytesBuilder(copy: false);
  parts.forEach(b.add);
  return b.takeBytes();
}

/// "yl-server-v1" | client_nonce | nonce | ts | cert_hash.
Uint8List serverPreimage(List<int> clientNonce, List<int> nonce, int ts, List<int> certHash) =>
    _cat([utf8.encode('yl-server-v1'), clientNonce, nonce, _be64(ts), certHash]);

/// "yl-auth-v1" | nonce | server_pub | ts.
Uint8List clientPreimage(List<int> nonce, List<int> serverPub, int ts) =>
    _cat([utf8.encode('yl-auth-v1'), nonce, serverPub, _be64(ts)]);

/// challenge из кадра сервера.
class Challenge {
  Challenge.fromMap(Map<String, Object?> m)
    : nonce = m['nonce']! as Uint8List,
      serverPub = m['server_pub']! as Uint8List,
      ts = m['ts']! as int,
      serverSig = m['server_sig']! as Uint8List,
      altSigs = [
        for (final a
            in ((m['alt_sigs'] as List<Object?>?) ?? const []).cast<Map<String, Object?>>())
          (h: a['h']! as Uint8List, s: a['s']! as Uint8List),
      ],
      unbound = m['unbound'] == true;

  final Uint8List nonce;
  final Uint8List serverPub;
  final int ts;
  final Uint8List serverSig;
  final List<({Uint8List h, Uint8List s})> altSigs;
  final bool unbound;
}

/// Почему challenge не принят — клиент рвёт соединение с понятной ошибкой.
enum ChallengeError {
  /// Ключ сервера не тот, что закреплён: «это не тот сервер».
  wrongServer,

  /// Сертификат TLS, который видит клиент, не подписан ключом сервера —
  /// возможна подмена.
  certNotSigned,
}

class ChallengeException implements Exception {
  const ChallengeException(this.error);
  final ChallengeError error;

  @override
  String toString() => 'ChallengeException(${error.name})';
}

final Ed25519 _ed = Ed25519();

Future<bool> _verify(List<int> pub, List<int> msg, List<int> sig) => _ed.verify(
  msg,
  signature: Signature(sig, publicKey: SimplePublicKey(pub, type: KeyPairType.ed25519)),
);

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}

/// Проверка клиента: ключ сервера закреплённый, подпись покрывает сертификат,
/// который клиент видит сам ([seenCertHash]; null — соединение без TLS).
/// true — сервер не знает свой сертификат (за прокси без tls.proxy_cert):
/// защиты от подмены нет, клиент предупреждает.
Future<bool> verifyChallenge(
  Challenge c, {
  required List<int> pinnedServerPub,
  required List<int> clientNonce,
  required List<int>? seenCertHash,
}) async {
  if (c.serverPub.length != 32 || !_same(c.serverPub, pinnedServerPub)) {
    throw const ChallengeException(ChallengeError.wrongServer);
  }
  if (c.unbound) {
    final ok = await _verify(
      c.serverPub,
      serverPreimage(clientNonce, c.nonce, c.ts, zeroCertHash),
      c.serverSig,
    );
    if (!ok) throw const ChallengeException(ChallengeError.wrongServer);
    return true;
  }
  if (seenCertHash == null) throw const ChallengeException(ChallengeError.certNotSigned);
  Future<bool> tryOne(List<int> h, List<int> sig) async =>
      _same(h, seenCertHash) &&
      await _verify(c.serverPub, serverPreimage(clientNonce, c.nonce, c.ts, h), sig);
  if (await tryOne(seenCertHash, c.serverSig)) return false;
  for (final a in c.altSigs) {
    if (await tryOne(a.h, a.s)) return false;
  }
  throw const ChallengeException(ChallengeError.certNotSigned);
}

/// Подпись клиента ключом устройства для auth.
Future<Uint8List> signAuth(
  List<int> deviceSeed,
  List<int> nonce,
  List<int> serverPub,
  int ts,
) async {
  final sig = await _ed.sign(
    clientPreimage(nonce, serverPub, ts),
    keyPair: await keyPairOf(deviceSeed),
  );
  return Uint8List.fromList(sig.bytes);
}

/// hello — первый кадр клиента. [deviceCert] — CBOR конверта Signed как есть.
Map<String, Object?> helloPayload({
  required List<int> masterPub,
  required List<int> devicePub,
  required Uint8List deviceCert,
  required Uint8List clientNonce,
  ({Uint8List session, int lastEvent})? resume,
}) => {
  'proto': protoVersion,
  'master_pub': Uint8List.fromList(masterPub),
  'device_pub': Uint8List.fromList(devicePub),
  'device_cert': deviceCert,
  'client_nonce': clientNonce,
  if (resume != null) 'resume': {'session': resume.session, 'last_event': resume.lastEvent},
};
