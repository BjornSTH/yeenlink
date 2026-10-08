import 'package:flutter/widgets.dart';

import '../icons/yl_icon.dart';
import '../theme/pending_tokens.dart';
import '../theme/yl_theme.dart';
import 'pressable.dart';

/// Модальное окно (AdminClaim): на ПК — карточка radius-2xl над scrim, на
/// телефоне — отдельный экран с «Назад» в шапке (AdminClaimPhone).
///
/// Ширину выбирает [showYlModal] по месту на экране.
class YlModal extends StatelessWidget {
  const YlModal({
    super.key,
    required this.title,
    required this.child,
    required this.phone,
    required this.closeLabel,
    this.onClose,
  });

  final String title;
  final Widget child;

  /// Экран телефона вместо карточки.
  final bool phone;

  /// Подпись кнопки «Закрыть» / «Назад» для чтения с экрана.
  final String closeLabel;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final close = onClose ?? () => Navigator.of(context).maybePop();
    if (phone) {
      return ColoredBox(
        color: c.bg100,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: YlPending.headerH,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: YlSpace.s1),
                  child: Row(
                    children: [
                      _IconButton(
                        icon: YlIconData.back,
                        label: closeLabel,
                        onTap: close,
                        size: YlSize.touchMin,
                        iconSize: YlPending.iconXl,
                        color: c.ink,
                      ),
                      const SizedBox(width: YlSpace.s1),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(title, style: YlText.title.copyWith(color: c.ink)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    YlSpace.s4,
                    YlSpace.s2,
                    YlSpace.s4,
                    YlSpace.s5,
                  ),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(YlSpace.s6),
        child: Container(
          width: YlPending.modalW,
          padding: const EdgeInsets.all(YlSpace.s6),
          decoration: BoxDecoration(
            color: c.bg100,
            borderRadius: YlRadius.xxl,
            border: Border.all(color: c.bg400),
            boxShadow: YlShadows.of(context).modal,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(title, style: YlText.title.copyWith(color: c.ink)),
                    ),
                  ),
                  _IconButton(
                    icon: YlIconData.close,
                    label: closeLabel,
                    onTap: close,
                    size: YlPending.closeButton,
                    iconSize: YlPending.iconMd,
                    color: c.muted,
                    bordered: true,
                  ),
                ],
              ),
              const SizedBox(height: YlSpace.s4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.size,
    required this.iconSize,
    required this.color,
    this.bordered = false,
  });

  final YlIconData icon;
  final String label;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final Color color;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, s) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: s.hovered || s.pressed ? c.bg300 : null,
          border: bordered || s.focused
              ? Border.all(
                  color: s.focused ? c.accent : c.border,
                  width: s.focused ? YlSize.focusRing : 1,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: YlIcon(icon, color: s.hovered ? c.ink : color, size: iconSize),
      ),
    );
  }
}

/// Показывает модальное окно: на узком экране — экраном на всю высоту.
Future<T?> showYlModal<T>(
  BuildContext context, {
  required String title,
  required String closeLabel,
  required bool phone,
  required Widget Function(BuildContext context) builder,
  bool dismissible = true,
}) {
  final c = YlColors.of(context);
  // Маршрут лежит вне экрана — базовый стиль текста задаём заново.
  Widget page(BuildContext ctx) => DefaultTextStyle(
    style: YlText.body.copyWith(color: c.ink),
    child: YlModal(
      title: title,
      phone: phone,
      closeLabel: closeLabel,
      child: Builder(builder: builder),
    ),
  );
  if (phone) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        pageBuilder: (ctx, _, _) => page(ctx),
        transitionsBuilder: (ctx, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: closeLabel,
    barrierColor: c.scrim,
    pageBuilder: (ctx, _, _) => page(ctx),
  );
}
