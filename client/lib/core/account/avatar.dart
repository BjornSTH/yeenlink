import 'package:crypto/crypto.dart' as hash;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../identity/payloads.dart';

/// Аватар, готовый к профилю: квадрат [side]×[side] PNG и его ссылка по хешу.
/// Загрузка на сервер — фаза 3 (blob.want → PUT /blob).
class AvatarImage {
  const AvatarImage(this.png, this.ref);

  final Uint8List png;
  final BlobRef ref;

  /// Сторона аватара в пикселях (spec/identity.md).
  static const side = 256;
}

class AvatarError implements Exception {
  const AvatarError();
}

/// Обрезает картинку по центру до квадрата, уменьшает до [AvatarImage.side]
/// и кодирует в PNG. Работает в отдельном изоляте.
Future<AvatarImage> prepareAvatar(Uint8List source) => compute(_prepare, source);

AvatarImage _prepare(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) throw const AvatarError();
  final side = decoded.width < decoded.height ? decoded.width : decoded.height;
  final square = img.copyCrop(
    decoded,
    x: (decoded.width - side) ~/ 2,
    y: (decoded.height - side) ~/ 2,
    width: side,
    height: side,
  );
  final small = img.copyResize(
    square,
    width: AvatarImage.side,
    height: AvatarImage.side,
    interpolation: img.Interpolation.average,
  );
  final png = Uint8List.fromList(img.encodePng(small, level: 9));
  if (png.length > Limits.avatarMaxBytes) throw const AvatarError();
  return AvatarImage(
    png,
    BlobRef(
      sha256: Uint8List.fromList(hash.sha256.convert(png).bytes),
      mime: 'image/png',
      size: png.length,
    ),
  );
}
