import 'package:flutter/widgets.dart';

import '../theme/yl_theme.dart';

/// Подложка экрана: фон из ступеней bg-000…bg-400 и базовый стиль текста
/// (body, ink). Без неё Text вне Material рисуется отладочным стилем.
class YlSurface extends StatelessWidget {
  const YlSurface({super.key, required this.child, this.color});

  final Widget child;

  /// Фон; по умолчанию bg-100 — основной фон окна.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return ColoredBox(
      color: color ?? c.bg100,
      child: DefaultTextStyle(
        style: YlText.body.copyWith(color: c.ink),
        child: child,
      ),
    );
  }
}
