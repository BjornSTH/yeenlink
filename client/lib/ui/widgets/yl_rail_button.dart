import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../icons/yl_icon.dart';
import '../theme/pending_tokens.dart';
import '../theme/yl_theme.dart';
import 'pressable.dart';

/// Круглая кнопка рельсы с пунктиром border-strong: «Добавить сервер»,
/// «Каталог серверов» (Main, EmptyServers, MobileApp).
class YlRailButton extends StatelessWidget {
  const YlRailButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.size = YlSize.railItem,
  });

  final YlIconData icon;
  final String label;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, s) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _DashedCircle(
            color: s.focused ? c.accent : c.borderStrong,
            fill: s.hovered || s.pressed ? c.bg300 : null,
            stroke: s.focused ? YlSize.focusRing : 1,
          ),
          child: Center(
            child: YlIcon(icon, color: s.hovered ? c.ink : c.muted, size: YlPending.iconLg),
          ),
        ),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  _DashedCircle({required this.color, required this.fill, required this.stroke});

  final Color color;
  final Color? fill;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    if (fill != null) canvas.drawCircle(center, r, Paint()..color = fill!);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final radius = r - stroke / 2;
    // Штрих и пробел — по три толщины, как CSS dashed.
    final dashes = (2 * math.pi * radius / (6 * stroke)).floor();
    final step = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step / 2,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) =>
      old.color != color || old.fill != fill || old.stroke != stroke;
}
