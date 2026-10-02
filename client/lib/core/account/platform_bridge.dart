import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Платформенные мелочи онбординга: модель телефона, «чувствительный» буфер
/// обмена, сохранение файла. На Android — свой канал (MainActivity.kt), на
/// ПК — file_selector и обычный буфер обмена.
class PlatformBridge {
  PlatformBridge();

  static const _channel = MethodChannel('yeenlink/platform');

  /// Через сколько очистить буфер обмена, если там всё ещё фраза.
  static const clipboardTtl = Duration(seconds: 60);

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// windows | linux | android | macos — как в device_cert.
  String get platform {
    if (Platform.isWindows) return 'windows';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    return 'linux';
  }

  /// Модель телефона (Build.MODEL) — для имени устройства по умолчанию.
  Future<String?> phoneModel() async {
    if (!isAndroid) return null;
    return _channel.invokeMethod<String>('deviceModel');
  }

  String? _sensitive;
  Timer? _ttl;

  /// Копирует текст; на Android 13+ помечает его как чувствительный, чтобы
  /// система не показывала превью. Буфер очищается через [clipboardTtl] или
  /// раньше, при закрытии приложения ([clearSensitiveClipboard]), если там всё
  /// ещё этот текст. Уход в фон буфер не трогает — фразу копируют, чтобы
  /// вставить в менеджер паролей.
  Future<void> copySensitive(String text) async {
    if (isAndroid) {
      await _channel.invokeMethod<void>('copySensitive', {'text': text});
    } else {
      await Clipboard.setData(ClipboardData(text: text));
    }
    _sensitive = text;
    _ttl?.cancel();
    _ttl = Timer(clipboardTtl, clearSensitiveClipboard);
  }

  /// Очищает буфер, если там всё ещё скопированная фраза. Если буфер прочитать
  /// нельзя (Android 10+ без фокуса — вернётся пусто), очищаем без сравнения:
  /// лишняя очистка безопаснее фразы, оставшейся в буфере.
  Future<void> clearSensitiveClipboard() async {
    final text = _sensitive;
    if (text == null) return;
    _sensitive = null;
    _ttl?.cancel();
    String? now;
    try {
      now = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } on Object {
      now = null;
    }
    if (now == null || now == text) await Clipboard.setData(const ClipboardData(text: ''));
  }

  /// Сохраняет текст в файл, место выбирает человек. false — отменил.
  Future<bool> saveText(String fileName, String text) async {
    if (isAndroid) {
      return await _channel.invokeMethod<bool>('saveText', {'name': fileName, 'text': text}) ??
          false;
    }
    final loc = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'txt', extensions: ['txt'], mimeTypes: ['text/plain']),
      ],
    );
    if (loc == null) return false;
    await File(loc.path).writeAsString(text);
    return true;
  }
}
