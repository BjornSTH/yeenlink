/// Категории ошибок кодека. Строки совпадают с Go (`server/pkg/codec`) и с
/// полем `error` в недопустимых векторах `testdata/vectors/codec`.
enum CodecErrorKind {
  malformed('malformed'),
  trailing('trailing'),
  dupKey('dup_key'),
  indefinite('indefinite'),
  tag('tag'),
  depth('depth'),
  size('size'),
  utf8('utf8'),
  simple('simple'),
  intRange('int_range'),
  keyType('key_type'),
  frameShape('frame_shape'),
  json('json');

  const CodecErrorKind(this.wire);

  /// Имя категории, общее с сервером.
  final String wire;
}

/// Ошибка кодирования или разбора.
class CodecException implements Exception {
  const CodecException(this.kind, this.message);

  final CodecErrorKind kind;
  final String message;

  @override
  String toString() => 'CodecException(${kind.wire}): $message';
}
