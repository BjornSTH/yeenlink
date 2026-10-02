import 'package:flutter/widgets.dart';

import '../../core/redact.dart';
import '../theme/yl_theme.dart';
import 'pressable.dart';

enum YlBannerKind {
  /// Янтарная: «переподключаюсь».
  warn,

  /// Зелёная: «работает через запасной адрес».
  ok,

  /// Красная: «сервер недоступен».
  err,
}

/// Полоса под шапкой чата о состоянии соединения
/// (docs/design/components/StatusBanner).
///
/// Текст говорит, что приложение делает само и что будет с сообщениями.
/// Адрес — моноширинным справа и всегда через redact. В красной полосе
/// одно действие — «Повторить сейчас». Без звука и мигания.
class YlStatusBanner extends StatelessWidget {
  const YlStatusBanner({
    super.key,
    required this.kind,
    required this.message,
    this.address,
    this.actionLabel,
    this.onAction,
  }) : assert(
         actionLabel == null || kind == YlBannerKind.err,
         'действие бывает только в красной полосе',
       );

  final YlBannerKind kind;
  final String message;

  /// Адрес, через который идёт попытка, — показывается через redact.
  final String? address;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final (bg, border, ink) = switch (kind) {
      YlBannerKind.warn => (c.warnBg, c.warnBorder, c.warnInk),
      YlBannerKind.ok => (c.okBg, c.okBorder, c.okInk),
      YlBannerKind.err => (c.errBg, c.errBorder, c.errInk),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: YlSize.bannerPadX,
          vertical: YlSize.bannerPadY,
        ),
        decoration: BoxDecoration(
          color: bg,
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(message, style: YlText.banner.copyWith(color: ink)),
            ),
            if (address != null) ...[
              const SizedBox(width: YlMetrics.bannerGap),
              RedactedText(RedactKind.address, address!, style: YlText.monoSm.copyWith(color: ink)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(width: YlMetrics.bannerGap),
              Pressable(
                onTap: onAction,
                builder: (context, s) => Container(
                  height: YlMetrics.bannerActionHeight,
                  padding: const EdgeInsets.symmetric(horizontal: YlSpace.s3),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.hovered || s.pressed ? border : null,
                    borderRadius: YlRadius.sm,
                    border: Border.all(
                      color: s.focused ? ink : border,
                      width: s.focused ? YlMetrics.focusRing : 1,
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: YlText.caption.copyWith(color: ink, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
