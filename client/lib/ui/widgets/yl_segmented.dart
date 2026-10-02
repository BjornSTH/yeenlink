import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/yl_theme.dart';
import 'pressable.dart';

/// Вариант сегментированного выбора.
class YlSegment<T> {
  const YlSegment(this.value, this.label, {this.available = true});

  final T value;
  final String label;

  /// Недоступный вариант не прячется: он помечается «· нет», а причина
  /// показывается рядом ([YlSegmented.note]).
  final bool available;
}

/// Выбор одного из 2–4 вариантов (docs/design/components/Segmented).
/// Больше четырёх — это уже список с радиокнопками.
class YlSegmented<T> extends StatelessWidget {
  const YlSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.note,
  }) : assert(segments.length >= 2 && segments.length <= 4, 'сегментов должно быть 2–4');

  final List<YlSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  /// Пояснение под выбором, например почему вариант недоступен.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l10n = L10n.of(context);
    final bar = Container(
      padding: const EdgeInsets.all(YlSize.segmentInset),
      decoration: BoxDecoration(color: c.bg000, borderRadius: YlRadius.md),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++) ...[
            if (i > 0) const SizedBox(width: YlSize.segmentInset),
            Expanded(child: _segment(c, l10n, segments[i])),
          ],
        ],
      ),
    );
    if (note == null) return bar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bar,
        const SizedBox(height: YlSpace.s2),
        Text(note!, style: YlText.caption.copyWith(color: c.muted)),
      ],
    );
  }

  Widget _segment(YlColors c, L10n l10n, YlSegment<T> seg) {
    final selected = seg.value == value;
    final enabled = seg.available && onChanged != null;
    return Pressable(
      onTap: enabled && !selected ? () => onChanged!(seg.value) : null,
      selected: selected,
      builder: (context, s) {
        final fg = !seg.available
            ? c.statusOffline
            : selected || s.hovered
            ? c.ink
            : c.subtle;
        return Container(
          height: YlSize.segmentH,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: selected ? c.bg400 : null, borderRadius: YlRadius.sm),
          foregroundDecoration: s.focused
              ? BoxDecoration(
                  borderRadius: YlRadius.sm,
                  border: Border.all(color: c.accent, width: YlSize.focusRing),
                )
              : null,
          child: Text(
            seg.available ? seg.label : l10n.segmentUnavailable(seg.label),
            style: YlText.label.copyWith(color: fg),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
