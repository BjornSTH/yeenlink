import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';

import 'codec_error.dart';
import 'strict.dart';

/// Единственный путь, которым клиент кодирует и разбирает CBOR. Профиль
/// общий с сервером (`server/pkg/codec`) и описан в `spec/README.md`.
///
/// Модель данных: `null`, `bool`, `int`, `double`, `String`, `Uint8List`,
/// `List<Object?>`, `Map<String, Object?>`.
///
/// Кодирование детерминированное: ключи по RFC 8949 §4.2.1, длины явные,
/// целые — кратчайшие, `double` — всегда 64 бита.
Uint8List ylEncode(Object? value) => Uint8List.fromList(cbor.encode(_toCbor(value, 0)));

/// Разбирает ровно одно значение CBOR со строгой проверкой.
Object? ylDecode(Uint8List data) {
  validateStrict(data);
  return _fromCbor(_decode(data));
}

/// Проверяет, что [data] — одно допустимое значение CBOR.
void ylValidate(Uint8List data) => validateStrict(data);

CborValue _decode(Uint8List data) {
  try {
    return cbor.decode(data);
  } on Object catch (e) {
    // Строгая проверка уже прошла, так что сюда попадают только
    // расхождения с пакетом cbor.
    throw CodecException(CodecErrorKind.malformed, '$e');
  }
}

/// Порядок ключей детерминированного CBOR: короче — раньше, при равной
/// длине — побайтово (длина и байты — в UTF-8).
int compareKeys(String a, String b) {
  final ab = utf8.encode(a);
  final bb = utf8.encode(b);
  if (ab.length != bb.length) return ab.length - bb.length;
  for (var i = 0; i < ab.length; i++) {
    if (ab[i] != bb[i]) return ab[i] - bb[i];
  }
  return 0;
}

/// Ключи словаря в каноническом порядке.
List<String> sortedKeys(Map<String, Object?> m) => m.keys.toList()..sort(compareKeys);

CborValue _toCbor(Object? v, int depth) {
  if (depth > maxDepth) {
    throw const CodecException(CodecErrorKind.depth, 'вложенность глубже $maxDepth');
  }
  return switch (v) {
    null => const CborNull(),
    bool b => CborBool(b),
    int i => CborSmallInt(i),
    double d => CborFloat(d)..doublePrecision(),
    String s => CborString(s),
    Uint8List b => CborBytes(b),
    List<Object?> l => CborList([
      for (final e in l) _toCbor(e, depth + 1),
    ], type: CborLengthType.definite),
    Map<String, Object?> m => CborMap({
      for (final k in sortedKeys(m)) CborString(k): _toCbor(m[k], depth + 1),
    }, type: CborLengthType.definite),
    _ => throw CodecException(CodecErrorKind.frameShape, 'тип ${v.runtimeType} не кодируется'),
  };
}

Object? _fromCbor(CborValue v) {
  return switch (v) {
    CborNull() => null,
    CborBool b => b.value,
    CborSmallInt i => i.value,
    CborInt i => _bigToInt(i.toBigInt()),
    CborFloat f => f.value,
    CborString s => s.toString(),
    CborBytes b => Uint8List.fromList(b.bytes),
    CborList l => [for (final e in l) _fromCbor(e)],
    CborMap m => {for (final e in m.entries) (e.key as CborString).toString(): _fromCbor(e.value)},
    _ => throw CodecException(CodecErrorKind.malformed, 'неожиданное значение ${v.runtimeType}'),
  };
}

int _bigToInt(BigInt b) {
  if (!b.isValidInt) throw const CodecException(CodecErrorKind.intRange, 'целое вне int64');
  return b.toInt();
}
