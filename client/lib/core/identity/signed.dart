import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../codec/codec.dart';
import 'keys.dart';

/// Типы конвертов. Ни один не начинается с другого: подписываемые байты
/// "yl-v1" | t | p склеиваются без разделителя (spec/identity.md).
abstract final class SignedType {
  static const profile = 'profile';
  static const post = 'post';
  static const deviceCert = 'device_cert';
  static const revoke = 'revoke';
  static const devices = 'devices';
  static const addresses = 'addresses';
  static const invite = 'invite';

  static const all = [profile, post, deviceCert, revoke, devices, addresses, invite];
}

/// Категории ошибок проверки; строки общие с Go и векторами.
enum IdentityError {
  unknownType('unknown_type'),
  wrongType('wrong_type'),
  badKey('bad_key'),
  badSignature('bad_signature'),
  badPayload('bad_payload'),
  signerMismatch('signer_mismatch');

  const IdentityError(this.wire);
  final String wire;
}

class IdentityException implements Exception {
  const IdentityException(this.error, this.message);

  final IdentityError error;
  final String message;

  @override
  String toString() => 'IdentityException(${error.wire}): $message';
}

const String _prefix = 'yl-v1';
final Ed25519 _ed = Ed25519();

/// Подписываемые байты: "yl-v1" | t | p.
Uint8List preimage(String t, List<int> p) =>
    (BytesBuilder(copy: false)
          ..add(utf8.encode(_prefix))
          ..add(utf8.encode(t))
          ..add(p))
        .takeBytes();

/// Подписанный конверт. [p] — CBOR-байты payload: кодируются один раз при
/// подписи и дальше никогда не пересобираются.
class Signed {
  const Signed(this.t, this.p, this.k, this.s);

  final String t;
  final Uint8List p;
  final Uint8List k;
  final Uint8List s;

  /// Кодирует payload в CBOR и подписывает ключом с seed [keySeed].
  static Future<Signed> sign(String t, Map<String, Object?> payload, List<int> keySeed) =>
      signBytes(t, ylEncode(payload), keySeed);

  static Future<Signed> signBytes(String t, Uint8List p, List<int> keySeed) async {
    if (!SignedType.all.contains(t)) {
      throw IdentityException(IdentityError.unknownType, 'тип «$t»');
    }
    final sig = await _ed.sign(preimage(t, p), keyPair: await keyPairOf(keySeed));
    return Signed(
      t,
      Uint8List.fromList(p),
      await publicKeyOf(keySeed),
      Uint8List.fromList(sig.bytes),
    );
  }

  /// Проверяет тип, ключ, подпись и то, что p — корректный CBOR-словарь.
  Future<void> verify() async {
    if (!SignedType.all.contains(t)) {
      throw IdentityException(IdentityError.unknownType, 'тип «$t»');
    }
    if (k.length != 32) throw IdentityException(IdentityError.badKey, 'ключ ${k.length} байт');
    final ok =
        s.length == 64 &&
        await _ed.verify(
          preimage(t, p),
          signature: Signature(s, publicKey: SimplePublicKey(k, type: KeyPairType.ed25519)),
        );
    if (!ok) throw const IdentityException(IdentityError.badSignature, 'подпись не сходится');
    payloadMap();
  }

  /// Payload как словарь модели данных (строгий разбор).
  Map<String, Object?> payloadMap() {
    try {
      final v = ylDecode(p);
      if (v is Map<String, Object?>) return v;
    } on CodecException catch (e) {
      throw IdentityException(IdentityError.badPayload, '$e');
    }
    throw const IdentityException(IdentityError.badPayload, 'payload не словарь');
  }

  Uint8List encode() => ylEncode({'t': t, 'p': p, 'k': k, 's': s});

  /// Разбирает конверт (подпись не проверяет — для неё [verify]).
  static Signed decode(Uint8List data) {
    final Object? v;
    try {
      v = ylDecode(data);
    } on CodecException catch (e) {
      throw IdentityException(IdentityError.badPayload, 'конверт: $e');
    }
    if (v is Map<String, Object?> &&
        v['t'] is String &&
        v['p'] is Uint8List &&
        v['k'] is Uint8List &&
        v['s'] is Uint8List) {
      return Signed(
        v['t']! as String,
        v['p']! as Uint8List,
        v['k']! as Uint8List,
        v['s']! as Uint8List,
      );
    }
    throw const IdentityException(IdentityError.badPayload, 'конверт: нужны t, p, k, s');
  }
}
