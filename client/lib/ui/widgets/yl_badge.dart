import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/yl_theme.dart';

enum _BadgeKind { live, bot, count }

/// Маленький маркер состояния: «ЭФИР», «БОТ», счётчик непрочитанных
/// (docs/design/components/Badge).
class YlBadge extends StatelessWidget {
  /// «ЭФИР» — accent + on-accent.
  const YlBadge.live({super.key}) : _kind = _BadgeKind.live, _count = 0;

  /// «БОТ» — служебный, bg-400 + muted.
  const YlBadge.bot({super.key}) : _kind = _BadgeKind.bot, _count = 0;

  /// Счётчик непрочитанных; больше 99 — «99+».
  const YlBadge.count(int count, {super.key}) : _kind = _BadgeKind.count, _count = count;

  final _BadgeKind _kind;
  final int _count;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l10n = L10n.of(context);

    if (_kind == _BadgeKind.count) {
      return Container(
        height: YlMetrics.counterSize,
        constraints: const BoxConstraints(minWidth: YlMetrics.counterSize),
        padding: const EdgeInsets.symmetric(horizontal: YlSize.badgePadX),
        decoration: BoxDecoration(color: c.accent, borderRadius: YlRadius.full),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _count > 99 ? l10n.badgeCountOverflow : '$_count',
              style: YlText.overline.copyWith(
                color: c.onAccent,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ],
        ),
      );
    }

    final live = _kind == _BadgeKind.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: YlSize.badgePadX, vertical: YlSize.badgePadY),
      decoration: BoxDecoration(color: live ? c.accent : c.bg400, borderRadius: YlRadius.xs),
      child: Text(
        live ? l10n.badgeLive : l10n.badgeBot,
        style: YlText.badge.copyWith(color: live ? c.onAccent : c.muted),
      ),
    );
  }
}
