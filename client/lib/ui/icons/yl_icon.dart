import 'package:flutter/widgets.dart';

import '../theme/tokens.g.dart';

/// Контурные иконки на сетке 24 (design/README.md, «Иконки»): обводка 1.8,
/// у мелких 16 px — 2, скруглённые концы и углы, без заливки.
enum YlIconData {
  /// Текстовый канал «#».
  hash,

  /// Голосовой канал — динамик.
  speaker,
}

class YlIcon extends StatelessWidget {
  const YlIcon(this.icon, {super.key, required this.color, this.size = 24});

  final YlIconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _IconPainter(icon, color)),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);

  final YlIconData icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final stroke = size.width <= YlMetrics.iconSm ? YlMetrics.iconStrokeSm : YlMetrics.iconStroke;
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_path(icon), paint);
  }

  // Пути — из превью ChannelRow (viewBox 0 0 24 24).
  static Path _path(YlIconData icon) => switch (icon) {
    YlIconData.hash =>
      Path()
        ..moveTo(5, 9)
        ..lineTo(19, 9)
        ..moveTo(4, 15)
        ..lineTo(18, 15)
        ..moveTo(10, 3)
        ..lineTo(8, 21)
        ..moveTo(16, 3)
        ..lineTo(14, 21),
    YlIconData.speaker =>
      Path()
        ..moveTo(11, 5)
        ..lineTo(6, 9)
        ..lineTo(3, 9)
        ..lineTo(3, 15)
        ..lineTo(6, 15)
        ..lineTo(11, 19)
        ..close()
        ..moveTo(15.5, 8.5)
        ..arcToPoint(const Offset(15.5, 15.5), radius: const Radius.circular(5)),
  };

  @override
  bool shouldRepaint(_IconPainter old) => old.icon != icon || old.color != color;
}
