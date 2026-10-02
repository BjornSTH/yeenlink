import 'package:flutter/widgets.dart';
import 'package:path_drawing/path_drawing.dart';

import '../theme/tokens.g.dart';

/// Контурные иконки на сетке 24 (design/README.md, «Иконки»): обводка 1.8,
/// у мелких 16 px — 2, скруглённые концы и углы. Пути — из макетов
/// (docs/mockups/src), viewBox 0 0 24 24; прямоугольники и окружности
/// переписаны путями.
enum YlIconData {
  /// Текстовый канал «#» (ChannelRow).
  hash(['M5 9h14M4 15h14M10 3 8 21M16 3l-2 18']),

  /// Голосовой канал — динамик (ChannelRow).
  speaker(['M11 5 6 9H3v6h3l5 4V5z', 'M15.5 8.5a5 5 0 0 1 0 7']),

  /// Знак логотипа: морда гиены (Onboarding).
  hyena(
    ['M5 4 8.5 10M19 4l-3.5 6', 'M6 13a6 6 0 0 0 12 0c0-2-1.5-3-3-3H9c-1.5 0-3 1-3 3z'],
    filled: [
      'M9.2 13.5a.8 .8 0 1 0 1.6 0a.8 .8 0 1 0 -1.6 0',
      'M13.2 13.5a.8 .8 0 1 0 1.6 0a.8 .8 0 1 0 -1.6 0',
    ],
  ),

  /// Сервер (Onboarding, «Сервер на дешёвом VPS»).
  server([
    'M5 4h14a2 2 0 0 1 2 2v3a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-3a2 2 0 0 1 2 -2z',
    'M5 13h14a2 2 0 0 1 2 2v3a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-3a2 2 0 0 1 2 -2z',
    'M7 7.5h.01M7 16.5h.01',
  ]),

  /// Человек (Onboarding, «Профиль всегда с вами»).
  user(['M8 8a4 4 0 1 0 8 0a4 4 0 1 0 -8 0', 'M4 21a8 8 0 0 1 16 0']),

  /// Ключ (Onboarding, «Ключ вместо пароля»).
  key(['M4 15a4 4 0 1 0 8 0a4 4 0 1 0 -8 0', 'm11 12 9-9M17 6l3 3M14 9l2 2']),

  /// Плюс (выбор аватара).
  plus(['M12 5v14M5 12h14']),

  /// Щит с галочкой (предупреждение о фразе).
  shield(['M12 3 5 6v6c0 4.5 3 7.5 7 9 4-1.5 7-4.5 7-9V6z', 'm9 12 2 2 4-4']),

  /// Скопировать.
  copy([
    'M10 8h8a2 2 0 0 1 2 2v8a2 2 0 0 1 -2 2h-8a2 2 0 0 1 -2 -2v-8a2 2 0 0 1 2 -2z',
    'M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3',
  ]),

  /// Сохранить в файл.
  download(['M12 4v11M7 10l5 5 5-5M5 20h14']),

  /// Каталог серверов — компас.
  compass(['M3 12a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'm15.5 8.5-2 5-5 2 2-5z']),

  /// Галочка (готово, отмеченный чекбокс).
  check(['m5 12 5 5 9-10']);

  const YlIconData(this.strokes, {this.filled = const []});

  /// Контуры (обводка).
  final List<String> strokes;

  /// Залитые части (глаза гиены).
  final List<String> filled;
}

class YlIcon extends StatelessWidget {
  const YlIcon(this.icon, {super.key, required this.color, this.size = 24, this.strokeWidth});

  final YlIconData icon;
  final Color color;
  final double size;

  /// По умолчанию icon-stroke, для иконок до icon-sm — icon-stroke-sm.
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _IconPainter(icon, color, strokeWidth)),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.strokeWidth);

  final YlIconData icon;
  final Color color;
  final double? strokeWidth;

  static final Map<String, Path> _cache = {};

  static Path _parse(String d) => _cache.putIfAbsent(d, () => parseSvgPathData(d));

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final stroke =
        strokeWidth ?? (size.width <= YlSize.iconSm ? YlSize.iconStrokeSm : YlSize.iconStroke);
    canvas.scale(scale);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke / scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final d in icon.strokes) {
      canvas.drawPath(_parse(d), line);
    }
    final fill = Paint()..color = color;
    for (final d in icon.filled) {
      canvas.drawPath(_parse(d), fill);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}
