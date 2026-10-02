import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/yl_theme.dart';
import 'pressable.dart';

/// Метка-таблетка: роль участника или реакция (docs/design/components/Chip).
/// Цвет роли живёт только в точке — чип целиком не красится.
class YlChip extends StatelessWidget {
  /// Роль: фон bg-300, точка цветом роли (role-*), текст ink.
  const YlChip.role({super.key, required this.label, required Color this.roleColor})
    : count = null,
      mine = false,
      onTap = null;

  /// Реакция «👍 · 4»: своя — рамка accent, чужая — рамка border и текст muted.
  const YlChip.reaction({
    super.key,
    required this.label,
    required int this.count,
    this.mine = false,
    this.onTap,
  }) : roleColor = null;

  final String label;
  final Color? roleColor;
  final int? count;
  final bool mine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final isReaction = count != null;
    final text = isReaction ? L10n.of(context).reactionCount(label, count!) : label;
    final fg = !isReaction || mine ? c.ink : c.muted;

    Widget body(bool hovered) => Container(
      height: YlSize.chipH,
      padding: const EdgeInsets.symmetric(horizontal: YlSize.chipPadX),
      decoration: BoxDecoration(
        color: !isReaction || mine ? c.bg300 : (hovered ? c.bg300 : null),
        borderRadius: YlRadius.full,
        border: isReaction ? Border.all(color: mine ? c.accent : c.border) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (roleColor != null) ...[
            Container(
              width: YlSize.chipDot,
              height: YlSize.chipDot,
              decoration: BoxDecoration(color: roleColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: YlSize.chipGap),
          ],
          Text(
            text,
            style: YlText.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );

    if (!isReaction) return body(false);
    return Pressable(onTap: onTap, toggled: mine, builder: (context, s) => body(s.hovered));
  }
}
