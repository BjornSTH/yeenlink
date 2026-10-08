import 'package:flutter/widgets.dart';

import '../icons/yl_icon.dart';
import '../theme/yl_theme.dart';
import 'pressable.dart';

enum YlButtonKind {
  /// Заливка accent — одна на экран или окно.
  primary,

  /// Прозрачная с рамкой border.
  secondary,

  /// Без рамки, текст muted: «Назад», «Отмена», «Пропустить пока».
  quiet,

  /// danger + on-danger — только для выхода из голоса. Удаление и отвязку
  /// пишите текстом danger-ink, не этой кнопкой.
  danger,
}

enum YlButtonSize {
  /// control-sm (32) — в строках.
  sm,

  /// control-lg (48) — онбординг и приглашения.
  lg,
}

/// Кнопка действия (docs/design/components/Button).
///
/// Без [onPressed] кнопка неактивна (bg-400 + muted), и тогда [label] должен
/// объяснять, чего не хватает: «Выберите, что показать».
class YlButton extends StatelessWidget {
  const YlButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = YlButtonKind.primary,
    this.size = YlButtonSize.lg,
    this.expand = false,
    this.icon,
  });

  final String label;

  /// Иконка слева от текста (icon-sm).
  final YlIconData? icon;
  final VoidCallback? onPressed;
  final YlButtonKind kind;
  final YlButtonSize size;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Pressable(
      onTap: onPressed,
      builder: (context, s) {
        var (bg, fg, border) = switch (kind) {
          YlButtonKind.primary => (c.accent, c.onAccent, null),
          YlButtonKind.secondary => (null, c.ink, s.hovered ? c.borderStrong : c.border),
          YlButtonKind.quiet => (null, s.hovered ? c.ink : c.muted, null),
          YlButtonKind.danger => (c.danger, c.onDanger, null),
        };
        if (!s.enabled) (bg, fg, border) = (c.bg400, c.muted, null);
        // Нажатое состояние прозрачных кнопок — bg-400 (tokens.json).
        if (s.enabled && s.pressed) bg ??= c.bg400;

        final base = size == YlButtonSize.lg ? YlText.button : YlText.label;
        final weight = kind == YlButtonKind.primary || kind == YlButtonKind.danger
            ? YlText.button.fontWeight
            : YlText.label.fontWeight;

        return Container(
          height: size == YlButtonSize.lg ? YlSize.controlLg : YlSize.controlSm,
          padding: EdgeInsets.symmetric(
            horizontal: size == YlButtonSize.lg ? YlSpace.s5 : YlSpace.s3,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: YlRadius.lg,
            border: border == null ? null : Border.all(color: border),
          ),
          foregroundDecoration: s.focused
              ? BoxDecoration(
                  borderRadius: YlRadius.lg,
                  border: Border.all(color: c.accent, width: YlSize.focusRing),
                )
              : null,
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                YlIcon(icon!, color: fg, size: YlSize.iconSm),
                const SizedBox(width: YlSpace.s2),
              ],
              Flexible(
                child: Text(
                  label,
                  style: base.copyWith(color: fg, fontWeight: weight),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
