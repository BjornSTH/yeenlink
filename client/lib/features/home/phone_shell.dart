import 'package:flutter/widgets.dart';

import '../../core/redact.dart';
import '../../core/servers/server_connection.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/icons/yl_icon.dart';
import '../../ui/illustrations/quiet_stone.dart';
import '../../ui/theme/pending_tokens.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/pressable.dart';
import 'home_parts.dart';

/// Вкладки нижней навигации телефона (MobileEmpty, MobileApp).
enum PhoneTab { servers, feed, dms, profile }

/// Нижняя навигация: Серверы, Лента, Личные, Профиль.
class PhoneNavBar extends StatelessWidget {
  const PhoneNavBar({super.key, required this.tab, required this.onTab});

  final PhoneTab tab;
  final ValueChanged<PhoneTab> onTab;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    final items = [
      (PhoneTab.servers, YlIconData.grid, l.navServers),
      (PhoneTab.feed, YlIconData.feed, l.navFeed),
      (PhoneTab.dms, YlIconData.bubble, l.navDms),
      (PhoneTab.profile, YlIconData.user, l.navProfile),
    ];
    return Container(
      decoration: BoxDecoration(
        color: c.bg000,
        border: Border(top: BorderSide(color: c.bg400)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: YlPending.bottomNavH,
          child: Row(
            children: [
              for (final (t, icon, label) in items)
                Expanded(
                  child: Pressable(
                    onTap: () => onTab(t),
                    semanticLabel: label,
                    selected: t == tab,
                    builder: (context, s) {
                      final color = t == tab ? c.accent : (s.hovered ? c.ink : c.subtle);
                      return Container(
                        color: s.pressed ? c.bg200 : null,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            YlIcon(icon, color: color, size: YlPending.iconXl),
                            const SizedBox(height: YlSpace.s1),
                            ExcludeSemantics(
                              child: Text(
                                label,
                                style: YlText.overline.copyWith(
                                  color: color,
                                  letterSpacing: 0,
                                  fontWeight: t == tab ? FontWeight.w700 : FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Панель выбранного сервера на телефоне (MobileApp): баннер с названием,
/// полосы состояния и содержимое (в фазе 2 — «нет владельца» или пусто).
class PhoneServerPanel extends StatelessWidget {
  const PhoneServerPanel({super.key, required this.conn, required this.onClaim});

  final ServerConnection conn;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(YlRadius.xlPx)),
      child: ColoredBox(
        color: c.bg200,
        child: ListenableBuilder(
          listenable: Listenable.merge([conn, streamerMode]),
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: YlPending.serverBannerH,
                color: c.hyenaBanner,
                padding: const EdgeInsets.fromLTRB(YlSpace.s3, YlSpace.s2, YlSpace.s3, YlSpace.s2),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serverTitle(context, conn.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YlText.title.copyWith(color: c.ink),
                    ),
                    if (conn.state == ConnState.online)
                      Text(l.srvOnline(1), style: YlText.caption.copyWith(color: c.inkSoft)),
                  ],
                ),
              ),
              ConnectionBanners(conn: conn),
              Expanded(
                child: ServerPlaceholder(conn: conn, onClaim: onClaim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Заглушка вкладки, которой ещё нет: «Лента», «Личные».
class PhoneTabPlaceholder extends StatelessWidget {
  const PhoneTabPlaceholder({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(YlSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const QuietStone(),
            const SizedBox(height: YlSpace.s5),
            Text(
              title,
              textAlign: TextAlign.center,
              style: YlText.h2.copyWith(color: c.ink),
            ),
            const SizedBox(height: YlSpace.s2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: YlText.bodyLg.copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}
