import 'package:flutter/widgets.dart';

import '../icons/yl_icon.dart';
import '../theme/yl_theme.dart';
import 'pressable.dart';

enum YlChannelKind { text, voice }

/// Строка канала в боковой колонке (docs/design/components/ChannelRow).
///
/// Выбранный — фон bg-400 и ink. Непрочитанный — ink и 700, без точек и
/// счётчиков, если нет упоминаний. Голосовой, в котором вы сейчас, —
/// иконка и таймер в status-online. Участников голосового под строкой
/// рисует колонка каналов (фаза 5).
class YlChannelRow extends StatelessWidget {
  const YlChannelRow({
    super.key,
    required this.name,
    this.kind = YlChannelKind.text,
    this.selected = false,
    this.unread = false,
    this.connected = false,
    this.timer,
    this.touch = false,
    this.onTap,
  });

  final String name;
  final YlChannelKind kind;
  final bool selected;
  final bool unread;

  /// Вы сейчас в этом голосовом канале.
  final bool connected;

  /// Сколько идёт голосовой канал, например «1:12:40».
  final String? timer;

  /// Телефон: строка выше (40 вместо 34).
  final bool touch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: name,
      builder: (context, s) {
        final fg = selected || unread || s.hovered ? c.ink : c.muted;
        final weight = unread
            ? FontWeight.w700
            : selected
            ? FontWeight.w600
            : FontWeight.w400;
        return Container(
          height: touch ? YlMetrics.channelRowHeightTouch : YlMetrics.channelRowHeight,
          padding: const EdgeInsets.symmetric(horizontal: YlSpace.s2),
          decoration: BoxDecoration(color: selected ? c.bg400 : null, borderRadius: YlRadius.sm),
          foregroundDecoration: s.focused
              ? BoxDecoration(
                  borderRadius: YlRadius.sm,
                  border: Border.all(color: c.accent, width: YlMetrics.focusRing),
                )
              : null,
          child: Row(
            children: [
              YlIcon(
                kind == YlChannelKind.text ? YlIconData.hash : YlIconData.speaker,
                color: connected ? c.statusOnline : c.subtle,
                size: YlMetrics.iconSm,
              ),
              const SizedBox(width: YlSpace.s2),
              Expanded(
                child: Text(
                  name,
                  style: YlText.body.copyWith(color: fg, fontWeight: weight, height: 1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (connected && timer != null)
                Text(timer!, style: YlText.monoXs.copyWith(color: c.statusOnline)),
            ],
          ),
        );
      },
    );
  }
}
