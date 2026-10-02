import 'package:flutter/widgets.dart';

import '../icons/yl_icon.dart';
import '../theme/yl_theme.dart';

/// Логотип: плитка accent со знаком гиены (logo-lg на ПК, logo-sm на телефоне)
/// и, по желанию, название рядом.
class YlLogo extends StatelessWidget {
  const YlLogo({super.key, this.size = YlSize.logoLg, this.withName = true, this.semanticLabel});

  final double size;
  final bool withName;

  /// Подпись для чтения с экрана; по умолчанию — название рядом.
  final String? semanticLabel;

  // Скругление плитки — 30 % стороны, знак — чуть больше половины
  // (tokens: logo-lg 48 → радиус 14, logo-sm 36 → радиус 11).
  static const _radiusShare = 0.3;
  static const _markShare = 0.54;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.accent,
        borderRadius: BorderRadius.circular((size * _radiusShare).roundToDouble()),
      ),
      alignment: Alignment.center,
      child: YlIcon(
        YlIconData.hyena,
        color: c.onAccent,
        size: (size * _markShare).roundToDouble(),
        strokeWidth: YlSize.iconStrokeSm,
      ),
    );
    if (!withName) return Semantics(label: semanticLabel, child: tile);
    final style = (size >= YlSize.logoLg ? YlText.h2 : YlText.title).copyWith(color: c.ink);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: tile),
        const SizedBox(width: YlSpace.s3),
        // Название продукта — не перевод, поэтому строка не в локализации.
        Text('YeenLink', style: style),
      ],
    );
  }
}
