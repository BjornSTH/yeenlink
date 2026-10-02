import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

import 'bip39.dart';
import 'slip10.dart';

/// Путь главного ключа: m/22860'/0'/i' (spec/identity.md).
/// 22860 = 0x594C, ASCII «YL»; 0' — ветка «личность»; i' — поколение ключа.
const int keyPurpose = 22860;
const int branchIdentity = 0;

List<int> masterPath(int generation) => [
  keyPurpose + hardened,
  branchIdentity + hardened,
  generation + hardened,
];

final Ed25519 _ed = Ed25519();

/// Главный ключ и всё, что выводится из фразы. Закрытый ключ держите в
/// памяти не дольше, чем нужно для подписи.
class Identity {
  Identity._(this.entropy, this.mnemonic, this.masterSeed, this.masterPub, this.nextPub)
    : nextKeyHash = Uint8List.fromList(hash.sha256.convert(nextPub).bytes);

  final Uint8List entropy;
  final String mnemonic;

  /// Закрытый главный ключ (seed Ed25519, 32 байта).
  final Uint8List masterSeed;
  final Uint8List masterPub;

  /// Открытый ключ следующего поколения (i = 1) и его SHA-256.
  final Uint8List nextPub;
  final Uint8List nextKeyHash;

  /// Проверяет фразу и выводит ключи. Ввод нормализуется. Проверка слов —
  /// сразу ([PhraseException]); вывод ключей (PBKDF2, SLIP-0010, Ed25519) —
  /// в отдельном изоляте, чтобы не останавливать интерфейс.
  static Future<Identity> fromMnemonic(String input) {
    final m = normalizeMnemonic(input);
    final entropy = mnemonicToEntropy(m);
    return Isolate.run(() => _derive(entropy, m));
  }

  /// Ключи из энтропии фразы (так она хранится под PIN); в отдельном изоляте.
  static Future<Identity> fromEntropy(List<int> entropy) {
    final e = Uint8List.fromList(entropy);
    final m = entropyToMnemonic(e);
    return Isolate.run(() => _derive(e, m));
  }

  static Future<Identity> _derive(Uint8List entropy, String mnemonic) async {
    final seed = await mnemonicToSeed(mnemonic);
    final cur = SlipNode.derive(seed, masterPath(0));
    final next = SlipNode.derive(seed, masterPath(1));
    return Identity._(
      entropy,
      mnemonic,
      cur.key,
      await publicKeyOf(cur.key),
      await publicKeyOf(next.key),
    );
  }

  Future<SimpleKeyPair> masterKeyPair() => keyPairOf(masterSeed);

  List<String> get words => mnemonic.split(' ');

  /// Затирает секреты в памяти, когда личность больше не нужна.
  void wipe() {
    entropy.fillRange(0, entropy.length, 0);
    masterSeed.fillRange(0, masterSeed.length, 0);
  }
}

Future<SimpleKeyPair> keyPairOf(List<int> seed) => _ed.newKeyPairFromSeed(seed);

Future<Uint8List> publicKeyOf(List<int> seed) async {
  final pub = await (await keyPairOf(seed)).extractPublicKey();
  return Uint8List.fromList(pub.bytes);
}

/// Отпечаток для людей: первые 8 байт SHA-256 открытого ключа, четыре группы
/// по 4 hex-символа через «·»: A0D2·5F11·8C3E·07B9. Показывать — через redact.
String fingerprint(List<int> pub) {
  final h = hash.sha256
      .convert(pub)
      .bytes
      .take(8)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  return [for (var i = 0; i < 16; i += 4) h.substring(i, i + 4)].join('·');
}

/// Первые две группы отпечатка, для карточек: A0D2·5F11.
String shortFingerprint(List<int> pub) => fingerprint(pub).substring(0, 9);

/// Номер цвета аватара без картинки в палитре из [n] цветов: первый байт
/// SHA-256 главного ключа по модулю [n] — одинаков на всех устройствах
/// (spec/identity.md). Та же функция в Go — identity.AvatarColorIndex.
int avatarColorIndex(List<int> masterPub, int n) => hash.sha256.convert(masterPub).bytes[0] % n;
