import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Блоб главного ключа под PIN или паролем (spec/identity.md, «Хранение»).
///
/// Внутри — энтропия фразы (16 байт): по ней восстанавливаются и фраза для
/// показа, и главный ключ. Формат (все целые — big-endian):
///
/// ```
/// "YLM1" | secret u8 | kdf u8 | memory_kib u32 | iterations u32 | parallelism u8
///        | salt 16 | nonce 24 | XChaCha20-Poly1305(key, entropy) + tag 16
/// key = Argon2id(secret, salt, memory_kib, iterations, parallelism) → 32 байта
/// AAD = "yl-master-v1" | master_pub | всё до шифротекста
/// ```
///
/// Параметры KDF лежат в блобе, поэтому их можно менять без миграции.
/// [SecretKind.password] — на фазу 7 («длинный пароль вместо PIN»).
enum SecretKind {
  pin(1),
  password(2);

  const SecretKind(this.code);
  final int code;
}

class KdfParams {
  const KdfParams({required this.memoryKib, required this.iterations, required this.parallelism});

  /// Основные параметры: Argon2id, 64 МиБ, 3 прохода.
  static const standard = KdfParams(memoryKib: 64 * 1024, iterations: 3, parallelism: 1);

  /// Запасные, если основные слишком медленные на устройстве (минимум OWASP).
  static const light = KdfParams(memoryKib: 19 * 1024, iterations: 2, parallelism: 1);

  final int memoryKib;
  final int iterations;
  final int parallelism;

  /// Во сколько раз эти параметры дороже [other] (память × проходы).
  double costRelativeTo(KdfParams other) =>
      memoryKib * iterations / (other.memoryKib * other.iterations);

  /// Выбирает параметры для этого устройства: прогоняет [light] и по его
  /// времени оценивает [standard]. Если оценка больше [budget] — берёт [light].
  static Future<KdfParams> choose({
    Duration budget = const Duration(milliseconds: 1500),
    Future<void> Function(KdfParams)? probe,
  }) async {
    final run = probe ?? MasterLock.deriveForProbe;
    final sw = Stopwatch()..start();
    await run(light);
    final estimate = sw.elapsedMicroseconds * standard.costRelativeTo(light);
    return estimate <= budget.inMicroseconds ? standard : light;
  }
}

/// PIN или пароль не подошёл (или блоб повреждён — различить нельзя).
class WrongSecret implements Exception {
  const WrongSecret();
}

class MasterLock {
  static const _magic = 'YLM1';
  static const _kdfArgon2id = 1;
  static const _aadPrefix = 'yl-master-v1';
  static const _headerLen = 4 + 1 + 1 + 4 + 4 + 1 + 16 + 24;

  static final _aead = Xchacha20.poly1305Aead();

  /// Шифрует энтропию фразы под секрет.
  static Future<Uint8List> seal({
    required List<int> entropy,
    required String secret,
    required SecretKind kind,
    required List<int> masterPub,
    KdfParams params = KdfParams.standard,
    List<int>? salt,
    List<int>? nonce,
  }) async {
    final s = salt ?? _random(16);
    final n = nonce ?? _random(24);
    final header = BytesBuilder()
      ..add(ascii.encode(_magic))
      ..addByte(kind.code)
      ..addByte(_kdfArgon2id)
      ..add(_u32(params.memoryKib))
      ..add(_u32(params.iterations))
      ..addByte(params.parallelism)
      ..add(s)
      ..add(n);
    final head = header.takeBytes();
    final box = await _aead.encrypt(
      entropy,
      secretKey: await _derive(secret, s, params),
      nonce: n,
      aad: _aad(masterPub, head),
    );
    return (BytesBuilder(copy: false)
          ..add(head)
          ..add(box.cipherText)
          ..add(box.mac.bytes))
        .takeBytes();
  }

  /// Расшифровывает энтропию. Неверный секрет — [WrongSecret].
  static Future<Uint8List> open({
    required Uint8List blob,
    required String secret,
    required List<int> masterPub,
  }) async {
    if (blob.length < _headerLen + 16 ||
        ascii.decode(blob.sublist(0, 4), allowInvalid: true) != _magic) {
      throw const FormatException('блоб главного ключа повреждён');
    }
    final bd = ByteData.sublistView(blob);
    if (blob[5] != _kdfArgon2id) throw FormatException('неизвестный KDF ${blob[5]}');
    final params = KdfParams(
      memoryKib: bd.getUint32(6),
      iterations: bd.getUint32(10),
      parallelism: blob[14],
    );
    final salt = blob.sublist(15, 31);
    final nonce = blob.sublist(31, _headerLen);
    final body = blob.sublist(_headerLen);
    try {
      final clear = await _aead.decrypt(
        SecretBox(
          body.sublist(0, body.length - 16),
          nonce: nonce,
          mac: Mac(body.sublist(body.length - 16)),
        ),
        secretKey: await _derive(secret, salt, params),
        aad: _aad(masterPub, blob.sublist(0, _headerLen)),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const WrongSecret();
    }
  }

  /// Только для замера в [KdfParams.choose].
  static Future<void> deriveForProbe(KdfParams p) async {
    await (await _derive('probe', List.filled(16, 0), p)).extractBytes();
  }

  /// Какой секрет защищает блоб — чтобы показать PIN-клавиатуру или поле пароля.
  static SecretKind kindOf(Uint8List blob) =>
      SecretKind.values.firstWhere((k) => k.code == blob[4], orElse: () => SecretKind.pin);

  static Future<SecretKey> _derive(String secret, List<int> salt, KdfParams p) => Argon2id(
    parallelism: p.parallelism,
    memory: p.memoryKib,
    iterations: p.iterations,
    hashLength: 32,
  ).deriveKey(secretKey: SecretKey(utf8.encode(secret)), nonce: salt);

  static List<int> _aad(List<int> masterPub, List<int> header) => [
    ...ascii.encode(_aadPrefix),
    ...masterPub,
    ...header,
  ];

  static List<int> _u32(int v) => (ByteData(4)..setUint32(0, v)).buffer.asUint8List();

  static List<int> _random(int n) => SecretKeyData.random(length: n).bytes;
}
