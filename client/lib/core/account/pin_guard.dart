import 'dart:math' as math;

import '../codec/codec.dart';
import '../vault/key_vault.dart';

/// Растущая пауза после неверных PIN — без стирания ключа (spec/identity.md).
/// Первые [freeAttempts] ошибок без паузы, дальше 30 с, 1 мин, 2 мин … до часа.
///
/// Это защита интерфейса от подбора руками. От офлайн-перебора защищают
/// системное хранилище и Argon2id.
class PinGuard {
  PinGuard(this._vault, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  static const key = 'yl.pin_guard.v1';
  static const freeAttempts = 5;
  static const firstPause = Duration(seconds: 30);
  static const maxPause = Duration(hours: 1);

  final KeyVault _vault;
  final DateTime Function() _now;

  Future<(int failures, int untilMs)> _load() async {
    final raw = await _vault.read(key);
    if (raw == null) return (0, 0);
    final m = ylDecode(raw)! as Map<String, Object?>;
    return (m['failures']! as int, m['until']! as int);
  }

  /// Сколько ещё ждать до следующей попытки; null — можно сейчас.
  Future<Duration?> wait() async {
    final (_, until) = await _load();
    final left = until - _now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : null;
  }

  Future<void> failed() async {
    final (failures, _) = await _load();
    final n = failures + 1;
    var until = 0;
    if (n >= freeAttempts) {
      final ms = firstPause.inMilliseconds * math.pow(2, n - freeAttempts);
      until = _now().millisecondsSinceEpoch + math.min(ms.toInt(), maxPause.inMilliseconds);
    }
    await _vault.write(key, ylEncode({'failures': n, 'until': until}));
  }

  Future<void> succeeded() => _vault.delete(key);
}
