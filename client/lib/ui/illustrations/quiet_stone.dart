import 'package:flutter/widgets.dart';

import '../theme/yl_theme.dart';

/// Камень с пятнами и луной — пустое состояние «Здесь пока тихо»
/// (EmptyServers, MobileEmpty). Координаты и размеры — из макета.
class QuietStone extends StatelessWidget {
  const QuietStone({super.key});

  static const _size = Size(160, 110);

  // left, top, width, height — пятна на камне.
  static const _spots = <(double, double, double, double)>[
    (34, 40, 30, 20),
    (88, 56, 40, 26),
    (70, 30, 16, 12),
  ];

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return ExcludeSemantics(
      child: SizedBox.fromSize(
        size: _size,
        child: Stack(
          children: [
            Positioned(
              left: 10,
              top: 20,
              width: 140,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.hyenaBanner,
                  borderRadius: const BorderRadius.all(Radius.circular(45)),
                ),
              ),
            ),
            for (final (l, t, w, h) in _spots)
              Positioned(
                left: l,
                top: t,
                width: w,
                height: h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.hyenaSpot,
                    borderRadius: BorderRadius.all(Radius.elliptical(w / 2, h / 2)),
                  ),
                ),
              ),
            Positioned(
              left: 112,
              top: 0,
              width: 34,
              height: 34,
              child: DecoratedBox(
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
