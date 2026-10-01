import 'dart:typed_data';

import 'package:cbor/cbor.dart';

import 'cbor_codec.dart';
import 'codec_error.dart';
import 'strict.dart';

/// Ошибка в ответе сервера.
class FrameError {
  const FrameError(this.code, [this.msg = '']);

  final String code;
  final String msg;
}

/// Кадр протокола клиент–сервер (spec/frame.cddl).
///
/// Запрос клиента несёт [id]; ответ сервера — тот же [id] и либо [d], либо
/// [e]. События сервера идут без [id]. [d] хранится сырыми байтами CBOR и
/// не пересобирается: обработчик операции разбирает его через [decodeD].
class Frame {
  Frame._(this.op, this.id, this.d, this.e) {
    if (op.isEmpty) throw const CodecException(CodecErrorKind.frameShape, 'нет op');
    if (id != null && id! < 0) {
      throw const CodecException(CodecErrorKind.frameShape, 'id отрицательный');
    }
    if (d != null && e != null) {
      throw const CodecException(CodecErrorKind.frameShape, 'в кадре одновременно d и e');
    }
    if (e != null && e!.code.isEmpty) {
      throw const CodecException(CodecErrorKind.frameShape, 'в ошибке нет code');
    }
  }

  /// Кадр с полем d из значения модели данных (`null` даёт `d: null`).
  factory Frame(String op, {int? id, Object? data}) => Frame._(op, id, ylEncode(data), null);

  /// Кадр без поля d.
  factory Frame.empty(String op, {int? id}) => Frame._(op, id, null, null);

  /// Ответ с ошибкой.
  factory Frame.error(String op, int? id, FrameError e) => Frame._(op, id, null, e);

  /// Кадр с уже закодированным d (байты остаются как есть).
  factory Frame.raw(String op, {int? id, Uint8List? d, FrameError? e}) => Frame._(op, id, d, e);

  final String op;
  final int? id;
  final Uint8List? d;
  final FrameError? e;

  /// Разбирает поле d в модель данных.
  Object? decodeD() {
    final raw = d;
    if (raw == null) {
      throw CodecException(CodecErrorKind.frameShape, 'в кадре «$op» нет поля d');
    }
    return ylDecode(raw);
  }

  /// Кодирует кадр в CBOR. Ключи по §4.2.1: d, e, id, op.
  Uint8List encode() {
    final out = BytesBuilder(copy: false);
    final fields = (d != null ? 1 : 0) + (e != null ? 1 : 0) + (id != null ? 1 : 0) + 1;
    out.addByte(0xa0 | fields);
    void key(String k) => out.add(cbor.encode(CborString(k)));
    if (d != null) {
      key('d');
      out.add(d!);
    }
    if (e != null) {
      key('e');
      out.add(ylEncode({'code': e!.code, 'msg': e!.msg}));
    }
    if (id != null) {
      key('id');
      out.add(ylEncode(id));
    }
    key('op');
    out.add(ylEncode(op));
    return out.takeBytes();
  }

  /// Разбирает и проверяет кадр CBOR.
  static Frame decode(Uint8List data) {
    final spans = validateStrict(data);
    final value = ylDecode(data);
    if (value is! Map<String, Object?> || spans == null) {
      throw const CodecException(CodecErrorKind.frameShape, 'кадр должен быть словарём');
    }
    final op = value['op'];
    final id = value['id'];
    final e = value['e'];
    if (op is! String) throw const CodecException(CodecErrorKind.frameShape, 'op не текст');
    if (id != null && id is! int) {
      throw const CodecException(CodecErrorKind.frameShape, 'id не целое');
    }
    FrameError? err;
    if (e != null) {
      if (e is! Map<String, Object?>) {
        throw const CodecException(CodecErrorKind.frameShape, 'e не словарь');
      }
      final code = e['code'] ?? '';
      final msg = e['msg'] ?? '';
      if (code is! String || msg is! String) {
        throw const CodecException(CodecErrorKind.frameShape, 'code и msg должны быть текстом');
      }
      err = FrameError(code, msg);
    }
    final dSpan = spans['d'];
    final d = dSpan == null ? null : Uint8List.fromList(data.sublist(dSpan.start, dSpan.end));
    return Frame._(op, id as int?, d, err);
  }
}
