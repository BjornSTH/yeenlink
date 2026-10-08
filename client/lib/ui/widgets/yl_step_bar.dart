import 'package:flutter/widgets.dart';

import '../theme/yl_theme.dart';

/// Полоса шагов: сегменты step-bar-h с зазором step-bar-gap, пройденные —
/// accent, остальные — border; под ней подпись «Шаг N из M».
class YlStepBar extends StatelessWidget {
  const YlStepBar({super.key, required this.step, required this.total, required this.caption});

  /// С единицы.
  final int step;
  final int total;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Semantics(
      label: caption,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) const SizedBox(width: YlSize.stepBarGap),
                  Expanded(
                    child: Container(
                      height: YlSize.stepBarH,
                      decoration: BoxDecoration(
                        color: i <= step ? c.accent : c.border,
                        borderRadius: YlRadius.full,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: YlSpace.s2),
            Text(caption, style: YlText.caption.copyWith(color: c.subtle)),
          ],
        ),
      ),
    );
  }
}
