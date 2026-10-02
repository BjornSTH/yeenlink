import 'package:flutter/widgets.dart';

import '../theme/yl_theme.dart';

/// Пятна гиены на левой колонке приветствия (Onboarding.dc.html) —
/// декоративная иллюстрация. Координаты и размеры — из макета, для колонки
/// onboarding-aside-w; эта папка исключена из проверки чисел в check_rules.
class AsideSpots extends StatelessWidget {
  const AsideSpots({super.key});

  // left, top, width, height — из макета.
  static const _spots = <(double, double, double, double)>[
    (380, 60, 120, 86),
    (440, 250, 60, 44),
    (60, 560, 90, 64),
    (330, 700, 140, 100),
    (200, 420, 44, 32),
    (470, 520, 70, 50),
  ];

  // В макете пятна #211D19 на bg-000 — это hyena-banner с такой прозрачностью.
  static const _opacity = 0.3;

  @override
  Widget build(BuildContext context) {
    final color = YlColors.of(context).hyenaBanner.withValues(alpha: _opacity);
    return ExcludeSemantics(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final (l, t, w, h) in _spots)
            Positioned(
              left: l,
              top: t,
              width: w,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
