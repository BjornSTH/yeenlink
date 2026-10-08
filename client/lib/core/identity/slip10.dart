import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;

/// Смещение hardened-индекса. Для ed25519 SLIP-0010 допускает только такие.
const int hardened = 0x80000000;

/// Узел SLIP-0010 для ed25519: закрытый ключ (seed Ed25519) и chain code.
class SlipNode {
  SlipNode._(this.key, this.chainCode);

  /// Корень: HMAC-SHA512("ed25519 seed", seed).
  factory SlipNode.master(List<int> seed) =>
      SlipNode._split(hash.Hmac(hash.sha512, utf8.encode('ed25519 seed')).convert(seed).bytes);

  factory SlipNode._split(List<int> i) =>
      SlipNode._(Uint8List.fromList(i.sublist(0, 32)), Uint8List.fromList(i.sublist(32)));

  final Uint8List key;
  final Uint8List chainCode;

  /// Hardened-потомок; [index] уже со смещением [hardened].
  SlipNode child(int index) {
    if (index < hardened || index > 0xFFFFFFFF) {
      throw ArgumentError('индекс $index не hardened, для ed25519 так нельзя');
    }
    final data = BytesBuilder()
      ..addByte(0)
      ..add(key)
      ..add((ByteData(4)..setUint32(0, index)).buffer.asUint8List());
    return SlipNode._split(hash.Hmac(hash.sha512, chainCode).convert(data.takeBytes()).bytes);
  }

  /// Узел по пути из seed.
  static SlipNode derive(List<int> seed, List<int> path) =>
      path.fold(SlipNode.master(seed), (n, i) => n.child(i));
}

/// Разбирает путь вида m/0'/1'.
List<int> parsePath(String s) {
  final parts = s.split('/');
  if (parts.first != 'm') throw FormatException('путь должен начинаться с m: $s');
  return [
    for (final p in parts.skip(1))
      if (p.endsWith("'"))
        int.parse(p.substring(0, p.length - 1)) + hardened
      else
        throw FormatException('элемент пути не hardened: $p'),
  ];
}
