import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:yeenlink/core/codec/codec.dart';

/// Общие векторы кодека (testdata/vectors/codec) — те же проверяет Go.
void main() {
  final dir = Directory(p.join('..', 'testdata', 'vectors', 'codec'));
  final manifests = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('векторы найдены', () => expect(manifests, isNotEmpty));

  for (final file in manifests) {
    final name = p.basenameWithoutExtension(file.path);
    test(name, () {
      final m = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final data = File(p.setExtension(file.path, '.cbor')).readAsBytesSync();

      if (m['valid'] != true) {
        expect(
          () => Frame.decode(data),
          throwsA(isA<CodecException>().having((e) => e.kind.wire, 'kind', m['error'])),
        );
        return;
      }

      final frame = Frame.decode(data);
      // Ожидаемое значение — через канонический CBOR, чтобы не зависеть от
      // форматирования JSON.
      final want = jsonToCbor(jsonEncode(m['frame']));
      final got = jsonToCbor(cborToJson(data));
      expect(got, want, reason: cborToJson(data));
      expect(_eq(want, data), m['canonical'], reason: 'canonical');

      // Тот же кадр через отладочный JSON на проводе.
      final jf = Wire.json.decodeFrame(utf8.encode(jsonEncode(m['frame'])));
      expect(jf.op, frame.op);
      expect(jf.id, frame.id);

      if (m['canonical'] == true) {
        expect(frame.encode(), data, reason: 'перекодированный кадр');
      }
    });
  }
}

bool _eq(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
