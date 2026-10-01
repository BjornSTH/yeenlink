import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:yeenlink/core/codec/codec.dart';

Matcher _throwsKind(CodecErrorKind kind) =>
    throwsA(isA<CodecException>().having((e) => e.kind, 'kind', kind));

void main() {
  test('кадр проходит через CBOR и JSON без изменений', () {
    final nonce = Uint8List.fromList(List.filled(32, 1));
    final f = Frame('challenge', data: {'nonce': nonce, 'ts': 1790000000000});
    for (final w in Wire.values) {
      final got = w.decodeFrame(w.encodeFrame(f));
      expect(got.op, 'challenge');
      expect(got.id, isNull);
      final d = got.decodeD()! as Map<String, Object?>;
      expect(d['nonce'], nonce);
      expect(d['ts'], 1790000000000);
    }
  });

  test('payload подписи внутри d не пересобирается', () {
    // {"b":1,"a":2} — ключи не по порядку.
    final payload = Uint8List.fromList([0xa2, 0x61, 0x62, 0x01, 0x61, 0x61, 0x02]);
    final f = Frame('profile.push', id: 5, data: {'p': payload});
    final d = Frame.decode(f.encode()).decodeD()! as Map<String, Object?>;
    expect(d['p'], payload);
  });

  test('сырой d в кадре сохраняется как есть', () {
    final raw = Uint8List.fromList([0xfa, 0x3f, 0xc0, 0x00, 0x00]); // float32 1.5
    final f = Frame.raw('test', d: raw);
    expect(Frame.decode(f.encode()).d, raw);
  });

  test('проверки кадра', () {
    expect(() => Frame.empty(''), _throwsKind(CodecErrorKind.frameShape));
    expect(
      () => Frame.raw('x', id: 1, d: ylEncode(0), e: const FrameError('c')),
      _throwsKind(CodecErrorKind.frameShape),
    );
    expect(() => Frame.error('x', 1, const FrameError('')), _throwsKind(CodecErrorKind.frameShape));
  });

  test('крайние случаи JSON', () {
    expect(() => cborToJson(ylEncode(double.nan)), _throwsKind(CodecErrorKind.json));
    expect(() => cborToJson(ylEncode({r'$bytes': 'x'})), _throwsKind(CodecErrorKind.json));
    expect(() => jsonToCbor('{"a":1,"a":2}'), _throwsKind(CodecErrorKind.dupKey));
    expect(() => jsonToCbor('18446744073709551615'), _throwsKind(CodecErrorKind.intRange));
    expect(() => jsonToCbor('{"op":"x"} 1'), _throwsKind(CodecErrorKind.trailing));
    expect(() => jsonToCbor('${'[' * 17}0${']' * 17}'), _throwsKind(CodecErrorKind.depth));
    // Целое и float различаются и после JSON.
    expect(jsonToCbor('[1, 1.0]'), [0x82, 0x01, 0xfb, 0x3f, 0xf0, 0, 0, 0, 0, 0, 0]);
  });

  test('порядок ключей: короче — раньше, затем побайтово', () {
    final keys = ['ключ', 'aa', 'b', 'Z', 'a'];
    keys.sort(compareKeys);
    expect(keys, ['Z', 'a', 'b', 'aa', 'ключ']);
  });
}
