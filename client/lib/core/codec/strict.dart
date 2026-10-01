import 'dart:convert';
import 'dart:typed_data';

import 'codec_error.dart';

/// Глубина — число вложенных контейнеров, кадр — первый.
const int maxDepth = 16;

/// Наибольшее число элементов массива или пар словаря.
const int maxItems = 16384;

/// Участок байтов внутри значения CBOR.
typedef ByteSpan = ({int start, int end});

/// Строгая проверка одного значения CBOR по профилю YeenLink
/// (spec/README.md): без тегов, длин без счётчика, undefined, дубликатов
/// ключей; ключи — только текст; целые — в пределах int64.
///
/// Пакет `cbor` всё это молча принимает, поэтому перед разбором байты
/// проходят здесь. Возвращает участки значений верхнего словаря — так кадр
/// получает поле `d` сырыми байтами, без перекодирования.
Map<String, ByteSpan>? validateStrict(Uint8List data) {
  final v = _Validator(data);
  final spans = v.item(1, wantSpans: true);
  if (v.pos != data.length) {
    throw const CodecException(CodecErrorKind.trailing, 'лишние байты после значения');
  }
  return spans;
}

class _Validator {
  _Validator(this.b) : bd = ByteData.sublistView(b);

  final Uint8List b;
  final ByteData bd;
  int pos = 0;

  Never _malformed(String msg) => throw CodecException(CodecErrorKind.malformed, msg);

  int _u8() {
    if (pos >= b.length) _malformed('значение оборвано');
    return b[pos++];
  }

  void _need(int n) {
    if (n < 0 || b.length - pos < n) _malformed('значение оборвано');
  }

  /// Аргумент заголовка. Для 8-байтового аргумента со старшим битом
  /// возвращает null: такое число не помещается в int64.
  ({int? arg, bool indefinite}) _arg(int ai) {
    if (ai < 24) return (arg: ai, indefinite: false);
    switch (ai) {
      case 24:
        return (arg: _u8(), indefinite: false);
      case 25:
        _need(2);
        pos += 2;
        return (arg: bd.getUint16(pos - 2), indefinite: false);
      case 26:
        _need(4);
        pos += 4;
        return (arg: bd.getUint32(pos - 4), indefinite: false);
      case 27:
        _need(8);
        pos += 8;
        final hi = bd.getUint32(pos - 8);
        if (hi & 0x80000000 != 0) return (arg: null, indefinite: false);
        return (arg: (hi << 32) | bd.getUint32(pos - 4), indefinite: false);
      case 31:
        return (arg: null, indefinite: true);
      default:
        _malformed('зарезервированное значение $ai в заголовке');
    }
  }

  Map<String, ByteSpan>? item(int depth, {bool wantSpans = false}) {
    final ib = _u8();
    final major = ib >> 5;
    final ai = ib & 0x1f;
    if (major == 7) {
      _simple(ai);
      return null;
    }
    final (:arg, :indefinite) = _arg(ai);
    if (indefinite) {
      if (major == 0 || major == 1 || major == 6) _malformed('длина без счётчика у типа $major');
      throw const CodecException(CodecErrorKind.indefinite, 'длина без счётчика');
    }
    switch (major) {
      case 0:
      case 1:
        if (arg == null) throw const CodecException(CodecErrorKind.intRange, 'целое вне int64');
        return null;
      case 2:
      case 3:
        final n = _len(arg);
        _need(n);
        if (major == 3) _utf8(pos, pos + n);
        pos += n;
        return null;
      case 4:
        _container(depth, arg);
        for (var i = 0; i < arg!; i++) {
          item(depth + 1);
        }
        return null;
      case 5:
        _container(depth, arg);
        final keys = <String>{};
        final spans = wantSpans ? <String, ByteSpan>{} : null;
        for (var i = 0; i < arg!; i++) {
          final key = _key();
          if (!keys.add(key)) {
            throw CodecException(CodecErrorKind.dupKey, 'ключ «$key» повторяется');
          }
          final start = pos;
          item(depth + 1);
          spans?[key] = (start: start, end: pos);
        }
        return spans;
      case 6:
        throw const CodecException(CodecErrorKind.tag, 'теги CBOR не допускаются');
    }
    _malformed('неизвестный тип $major');
  }

  void _container(int depth, int? count) {
    if (depth > maxDepth) {
      throw const CodecException(CodecErrorKind.depth, 'вложенность глубже $maxDepth');
    }
    if (count == null || count > maxItems) {
      throw const CodecException(CodecErrorKind.size, 'коллекция больше $maxItems');
    }
  }

  int _len(int? arg) {
    if (arg == null || arg > b.length) _malformed('длина больше входа');
    return arg;
  }

  String _key() {
    final ib = _u8();
    if (ib >> 5 != 3) {
      pos--;
      throw const CodecException(CodecErrorKind.keyType, 'ключ словаря не текст');
    }
    final (:arg, :indefinite) = _arg(ib & 0x1f);
    if (indefinite) throw const CodecException(CodecErrorKind.indefinite, 'длина без счётчика');
    final n = _len(arg);
    _need(n);
    final s = _utf8(pos, pos + n);
    pos += n;
    return s;
  }

  String _utf8(int start, int end) {
    try {
      return utf8.decode(Uint8List.sublistView(b, start, end));
    } on FormatException {
      throw const CodecException(CodecErrorKind.utf8, 'текст не в UTF-8');
    }
  }

  void _simple(int ai) {
    switch (ai) {
      case 20: // false
      case 21: // true
      case 22: // null
        return;
      case 25:
        _need(2);
        pos += 2;
        return;
      case 26:
        _need(4);
        pos += 4;
        return;
      case 27:
        _need(8);
        pos += 8;
        return;
      case 24:
        _u8();
        throw const CodecException(CodecErrorKind.simple, 'простое значение');
      case 28:
      case 29:
      case 30:
      case 31:
        _malformed('недопустимое простое значение $ai');
    }
    throw const CodecException(CodecErrorKind.simple, 'простое значение (в том числе undefined)');
  }
}
