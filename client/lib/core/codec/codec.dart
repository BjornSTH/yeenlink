/// Общий кодек кадров: CBOR, отладочный JSON и кадр протокола.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'frame.dart';
import 'json_debug.dart';

export 'cbor_codec.dart' show compareKeys, sortedKeys, ylDecode, ylEncode, ylValidate;
export 'codec_error.dart';
export 'frame.dart';
export 'json_debug.dart' show bytesKey, cborToJson, jsonToCbor;
export 'strict.dart' show maxDepth, maxItems;

/// Формат кадров на проводе: CBOR — рабочий, JSON — отладочный
/// (сервер с флагом `--codec=json`).
enum Wire {
  cbor,
  json;

  /// Кодирует кадр для отправки: байты для CBOR, UTF-8 текст для JSON.
  Uint8List encodeFrame(Frame f) {
    final b = f.encode();
    return this == cbor ? b : utf8.encode(cborToJson(b));
  }

  /// Разбирает принятый кадр.
  Frame decodeFrame(Uint8List data) =>
      Frame.decode(this == cbor ? data : jsonToCbor(utf8.decode(data)));
}
