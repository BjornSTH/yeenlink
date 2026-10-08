import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Хранилище секретов: блоб главного ключа, seed ключа устройства, счётчик
/// попыток PIN. Подменяется в тестах и Docker (spec/identity.md, «Хранение»).
///
/// Записи маленькие (до ~200 байт): на Windows одна запись Диспетчера учётных
/// данных ограничена 2560 байтами. Несекретное (подписанный профиль, аватар)
/// здесь не хранится.
abstract interface class KeyVault {
  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List value);
  Future<void> delete(String key);
}

/// Системное хранилище: Android Keystore, Диспетчер учётных данных Windows
/// (DPAPI), libsecret на Linux.
class SecureVault implements KeyVault {
  SecureVault()
    : _storage = const FlutterSecureStorage(
        // При ошибке Keystore пакет по умолчанию стирает всё — ключи не должны
        // пропадать молча; ошибку увидит человек.
        aOptions: AndroidOptions(resetOnError: false),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<Uint8List?> read(String key) async {
    final v = await _storage.read(key: key);
    return v == null ? null : base64Decode(v);
  }

  @override
  Future<void> write(String key, Uint8List value) =>
      _storage.write(key: key, value: base64Encode(value));

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// В памяти — для тестов.
class MemoryVault implements KeyVault {
  final Map<String, Uint8List> _data = {};

  @override
  Future<Uint8List?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, Uint8List value) async => _data[key] = Uint8List.fromList(value);

  @override
  Future<void> delete(String key) async => _data.remove(key);

  /// Для тестов: что сейчас лежит в хранилище.
  Map<String, Uint8List> get debugContents => Map.unmodifiable(_data);
}

/// Незашифрованный файл — только для отладочных сборок в Docker и на машинах
/// без системного хранилища. Включается `--dart-define=YL_VAULT=file`.
class FileVault implements KeyVault {
  FileVault(this.file) {
    if (!kDebugMode) throw StateError('FileVault разрешён только в отладочной сборке');
    debugPrint('ВНИМАНИЕ: ключи хранятся без шифрования в ${file.path}');
  }

  final File file;

  Future<Map<String, String>> _load() async {
    if (!file.existsSync()) return {};
    return (jsonDecode(await file.readAsString()) as Map<String, dynamic>).cast<String, String>();
  }

  Future<void> _save(Map<String, String> data) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(data));
  }

  @override
  Future<Uint8List?> read(String key) async {
    final v = (await _load())[key];
    return v == null ? null : base64Decode(v);
  }

  @override
  Future<void> write(String key, Uint8List value) async =>
      _save((await _load())..[key] = base64Encode(value));

  @override
  Future<void> delete(String key) async => _save((await _load())..remove(key));
}
