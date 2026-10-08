import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

import 'wordlist_en.dart';

/// Почему фраза не подошла. Те же категории — в векторах
/// testdata/vectors/identity/keys.json (`bad_mnemonic`).
enum PhraseError {
  wordCount('word_count'),
  unknownWord('unknown_word'),
  checksum('checksum');

  const PhraseError(this.wire);
  final String wire;
}

class PhraseException implements Exception {
  const PhraseException(this.error, [this.index]);

  final PhraseError error;

  /// Номер неизвестного слова (с нуля) для [PhraseError.unknownWord].
  final int? index;

  @override
  String toString() => 'PhraseException(${error.wire}${index == null ? '' : ', $index'})';
}

final Map<String, int> _index = {for (var i = 0; i < bip39English.length; i++) bip39English[i]: i};

/// Ввод к виду BIP39: нижний регистр, слова через один пробел. Слова списка —
/// ASCII, поэтому NFKD из BIP39 ничего не меняет, а не-ASCII даст ошибку слова.
String normalizeMnemonic(String s) =>
    s.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');

/// Кодирует энтропию (16–32 байта, кратно 4) во фразу.
String entropyToMnemonic(List<int> entropy) {
  final n = entropy.length;
  if (n < 16 || n > 32 || n % 4 != 0) {
    throw ArgumentError('энтропия $n байт, нужно 16–32 кратно 4');
  }
  final bits = [...entropy, hash.sha256.convert(entropy).bytes[0]];
  final count = (n * 8 + n * 8 ~/ 32) ~/ 11;
  final words = <String>[];
  for (var i = 0; i < count; i++) {
    var idx = 0;
    for (var b = 0; b < 11; b++) {
      final pos = i * 11 + b;
      idx = (idx << 1) | ((bits[pos ~/ 8] >> (7 - pos % 8)) & 1);
    }
    words.add(bip39English[idx]);
  }
  return words.join(' ');
}

/// Проверяет нормализованную фразу и возвращает энтропию.
Uint8List mnemonicToEntropy(String mnemonic) {
  final words = mnemonic.split(' ');
  if (![12, 15, 18, 21, 24].contains(words.length)) {
    throw const PhraseException(PhraseError.wordCount);
  }
  final total = words.length * 11;
  final csBits = total ~/ 33;
  final entBytes = (total - csBits) ~/ 8;
  final bits = Uint8List((total + 7) ~/ 8);
  for (var i = 0; i < words.length; i++) {
    final idx = _index[words[i]];
    if (idx == null) throw PhraseException(PhraseError.unknownWord, i);
    for (var b = 0; b < 11; b++) {
      if ((idx >> (10 - b)) & 1 == 1) {
        final pos = i * 11 + b;
        bits[pos ~/ 8] |= 1 << (7 - pos % 8);
      }
    }
  }
  final entropy = Uint8List.fromList(bits.sublist(0, entBytes));
  final sum = hash.sha256.convert(entropy).bytes[0];
  if (bits[entBytes] >> (8 - csBits) != sum >> (8 - csBits)) {
    throw const PhraseException(PhraseError.checksum);
  }
  return entropy;
}

/// Seed BIP39: PBKDF2-HMAC-SHA512(фраза, "mnemonic" + пароль, 2048), 64 байта.
/// YeenLink использует пустой пароль; непустой — только для официальных
/// векторов (ASCII, поэтому без NFKD).
Future<Uint8List> mnemonicToSeed(String mnemonic, [String passphrase = '']) async {
  final kdf = Pbkdf2(macAlgorithm: Hmac.sha512(), iterations: 2048, bits: 512);
  final key = await kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(mnemonic)),
    nonce: utf8.encode('mnemonic$passphrase'),
  );
  return Uint8List.fromList(await key.extractBytes());
}
