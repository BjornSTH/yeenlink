import 'dart:convert';
import 'dart:typed_data';

import 'cbor_codec.dart';
import 'codec_error.dart';
import 'strict.dart';

/// Отладочный JSON — представление модели данных CBOR (spec/json-debug.md):
///
/// - байтовая строка — `{"$bytes": "<base64url без =>"}`;
/// - `double` всегда с точкой или экспонентой, целое — без;
/// - ключи — только текст, выводятся в порядке CBOR (§4.2.1).
const String bytesKey = r'$bytes';

/// Переводит одно значение CBOR в отладочный JSON.
String cborToJson(Uint8List data, {String indent = ''}) {
  final out = StringBuffer();
  _write(out, ylDecode(data), indent, 0);
  return out.toString();
}

/// Переводит отладочный JSON в детерминированный CBOR.
Uint8List jsonToCbor(String text) {
  final p = _Parser(text);
  p.ws();
  final v = p.value(0);
  p.ws();
  if (p.pos != text.length) {
    throw const CodecException(CodecErrorKind.trailing, 'лишние данные после JSON');
  }
  return ylEncode(v);
}

void _write(StringBuffer out, Object? v, String indent, int level) {
  void nl(int l) {
    if (indent.isEmpty) return;
    out
      ..write('\n')
      ..write(indent * l);
  }

  switch (v) {
    case null:
      out.write('null');
    case bool b:
      out.write(b);
    case int i:
      out.write(i);
    case double d:
      if (d.isNaN || d.isInfinite) {
        throw CodecException(CodecErrorKind.json, '$d не представимо в JSON');
      }
      var s = d.toString();
      if (!s.contains('.') && !s.contains('e') && !s.contains('E')) s = '$s.0';
      out.write(s);
    case String s:
      out.write(jsonEncode(s));
    case Uint8List b:
      out.write('{"$bytesKey":${jsonEncode(base64Url.encode(b).replaceAll('=', ''))}}');
    case List<Object?> l:
      out.write('[');
      for (var i = 0; i < l.length; i++) {
        if (i > 0) out.write(',');
        nl(level + 1);
        _write(out, l[i], indent, level + 1);
      }
      if (l.isNotEmpty) nl(level);
      out.write(']');
    case Map<String, Object?> m:
      if (m.length == 1 && m.containsKey(bytesKey)) {
        throw const CodecException(
          CodecErrorKind.json,
          'словарь с единственным ключом \$bytes неотличим от байтов',
        );
      }
      out.write('{');
      final keys = sortedKeys(m);
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        nl(level + 1);
        out
          ..write(jsonEncode(keys[i]))
          ..write(indent.isEmpty ? ':' : ': ');
        _write(out, m[keys[i]], indent, level + 1);
      }
      if (keys.isNotEmpty) nl(level);
      out.write('}');
    default:
      throw CodecException(CodecErrorKind.json, 'неожиданный тип ${v.runtimeType}');
  }
}

/// Небольшой разборщик JSON: стандартный jsonDecode молча берёт последний из
/// повторяющихся ключей и не ограничивает глубину.
class _Parser {
  _Parser(this.s);

  final String s;
  int pos = 0;

  Never _fail(String msg) => throw CodecException(CodecErrorKind.json, '$msg (позиция $pos)');

  void ws() {
    while (pos < s.length && ' \t\r\n'.contains(s[pos])) {
      pos++;
    }
  }

  void _expect(String c) {
    ws();
    if (pos >= s.length || s[pos] != c) _fail('ожидалось «$c»');
    pos++;
  }

  Object? value(int depth) {
    ws();
    if (pos >= s.length) _fail('JSON оборван');
    final c = s[pos];
    if (c == '{' || c == '[') {
      if (depth >= maxDepth) {
        throw const CodecException(CodecErrorKind.depth, 'вложенность глубже $maxDepth');
      }
      return c == '{' ? _object(depth) : _array(depth);
    }
    if (c == '"') return _string();
    for (final (word, v) in const [('true', true), ('false', false), ('null', null)]) {
      if (s.startsWith(word, pos)) {
        pos += word.length;
        return v;
      }
    }
    return _number();
  }

  List<Object?> _array(int depth) {
    pos++;
    final out = <Object?>[];
    ws();
    if (pos < s.length && s[pos] == ']') {
      pos++;
      return out;
    }
    while (true) {
      if (out.length == maxItems) {
        throw const CodecException(CodecErrorKind.size, 'массив больше $maxItems');
      }
      out.add(value(depth + 1));
      ws();
      if (pos < s.length && s[pos] == ',') {
        pos++;
        continue;
      }
      _expect(']');
      return out;
    }
  }

  Object _object(int depth) {
    pos++;
    final out = <String, Object?>{};
    ws();
    if (pos < s.length && s[pos] == '}') {
      pos++;
      return out;
    }
    while (true) {
      ws();
      if (pos >= s.length || s[pos] != '"') _fail('ключ должен быть строкой');
      final k = _string();
      if (out.containsKey(k)) {
        throw CodecException(CodecErrorKind.dupKey, 'ключ «$k» повторяется');
      }
      if (out.length == maxItems) {
        throw const CodecException(CodecErrorKind.size, 'словарь больше $maxItems');
      }
      _expect(':');
      out[k] = value(depth + 1);
      ws();
      if (pos < s.length && s[pos] == ',') {
        pos++;
        continue;
      }
      _expect('}');
      break;
    }
    if (out.length == 1 && out.containsKey(bytesKey)) {
      final b64 = out[bytesKey];
      if (b64 is! String) _fail('$bytesKey должен быть строкой');
      try {
        return base64Url.decode(base64Url.normalize(b64));
      } on FormatException {
        _fail('$bytesKey: не base64url');
      }
    }
    return out;
  }

  String _string() {
    final start = pos;
    pos++;
    while (pos < s.length) {
      final c = s[pos];
      if (c == r'\') {
        pos += 2;
        continue;
      }
      pos++;
      if (c == '"') {
        try {
          return jsonDecode(s.substring(start, pos)) as String;
        } on FormatException {
          _fail('строка с ошибкой');
        }
      }
    }
    _fail('строка не закрыта');
  }

  Object _number() {
    final m = RegExp(r'-?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?').matchAsPrefix(s, pos);
    if (m == null || m.end == pos) _fail('неожиданный символ');
    pos = m.end;
    final text = m[0]!;
    if (m[2] != null || m[3] != null) return double.parse(text);
    final i = int.tryParse(text);
    if (i == null) throw CodecException(CodecErrorKind.intRange, 'целое $text вне int64');
    return i;
  }
}
