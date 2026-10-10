import 'package:flutter/widgets.dart';

import '../../core/account/account_store.dart';
import '../../core/identity/identity.dart';
import '../../core/redact.dart';
import '../../core/servers/server_connection.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/icons/yl_icon.dart';
import '../../ui/theme/pending_tokens.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/widgets.dart';
import 'home_parts.dart';

/// Колонка каналов (Main, aside «Каналы»): шапка с названием сервера,
/// каналы (в фазе 2 — пусто) и панель пользователя внизу.
class ChannelColumn extends StatelessWidget {
  const ChannelColumn({super.key, required this.conn, required this.account});

  final ServerConnection conn;
  final LocalAccount account;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    return Container(
      width: YlSize.channelColumnW,
      color: c.bg200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColumnHeader(
            child: Row(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([conn, streamerMode]),
                    builder: (context, _) => Text(
                      serverTitle(context, conn.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YlText.button.copyWith(color: c.ink),
                    ),
                  ),
                ),
                YlIcon(YlIconData.chevronDown, color: c.muted, size: YlSize.iconSm),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: YlSpace.s4, vertical: YlSpace.s4),
              child: ListenableBuilder(
                listenable: conn,
                builder: (context, _) => conn.state == ConnState.online
                    ? Text(l.srvNoChannelsTitle, style: YlText.caption.copyWith(color: c.subtle))
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          UserPanel(account: account),
        ],
      ),
    );
  }
}

/// Панель «я» внизу колонки каналов: аватар, имя, короткий отпечаток.
/// Микрофон, звук и настройки появятся вместе с голосом и настройками.
class UserPanel extends StatelessWidget {
  const UserPanel({super.key, required this.account});

  final LocalAccount account;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: streamerMode,
      builder: (context, _, _) {
        final me = MeInfo(account, l, c.avatarPalette.length);
        return Container(
          height: YlPending.userPanelH,
          color: c.bg000,
          padding: const EdgeInsets.symmetric(horizontal: YlSpace.s3),
          child: Row(
            children: [
              YlAvatar.user(
                name: me.name,
                colorIndex: me.colorIndex,
                fallbackInitials: me.fallbackInitials,
                size: YlSize.avatarSm,
                status: YlStatus.online,
                image: me.avatar,
                background: c.bg000,
              ),
              const SizedBox(width: YlSpace.s3),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me.name ?? l.homeNoName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: YlText.label.copyWith(color: c.ink, fontWeight: FontWeight.w700),
                    ),
                    RedactedText(
                      RedactKind.fingerprint,
                      shortFingerprint(account.masterPub),
                      style: YlText.monoXs.copyWith(color: c.subtle),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Середина: шапка, полосы состояния, содержимое сервера.
class ChatArea extends StatelessWidget {
  const ChatArea({super.key, required this.conn, required this.onClaim});

  final ServerConnection conn;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return ColoredBox(
      color: c.bg100,
      child: ListenableBuilder(
        listenable: Listenable.merge([conn, streamerMode]),
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ColumnHeader(
              padX: YlSpace.s5,
              child: Text(
                serverTitle(context, conn.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: YlText.button.copyWith(color: c.ink),
              ),
            ),
            ConnectionBanners(conn: conn),
            Expanded(
              child: ServerPlaceholder(conn: conn, onClaim: onClaim),
            ),
          ],
        ),
      ),
    );
  }
}

/// Колонка участников (Main, aside «Участники сервера»). В фазе 2 сервер
/// ещё не присылает список — видно только себя.
class MembersColumn extends StatelessWidget {
  const MembersColumn({super.key, required this.conn, required this.account});

  final ServerConnection conn;
  final LocalAccount account;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    return Container(
      width: YlPending.membersColumnW,
      decoration: BoxDecoration(
        color: c.bg200,
        border: Border(left: BorderSide(color: c.bg400)),
      ),
      child: ListenableBuilder(
        listenable: Listenable.merge([conn, streamerMode]),
        builder: (context, _) {
          final online = conn.state == ConnState.online;
          final me = MeInfo(account, l, c.avatarPalette.length);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ColumnHeader(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.srvMembers,
                        style: YlText.body.copyWith(color: c.ink, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (online)
                      Text(l.srvOnline(1), style: YlText.caption.copyWith(color: c.subtle)),
                  ],
                ),
              ),
              if (online)
                Padding(
                  padding: const EdgeInsets.all(YlSpace.s2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          YlSpace.s2,
                          YlSpace.s3,
                          YlSpace.s2,
                          YlSpace.s1,
                        ),
                        child: Text(
                          conn.isOwner ? l.srvGroupOwner(1) : l.srvGroupOnline(1),
                          style: YlText.overline.copyWith(color: c.subtle),
                        ),
                      ),
                      SelfMemberRow(
                        name: me.name,
                        colorIndex: me.colorIndex,
                        fallbackInitials: me.fallbackInitials,
                        avatar: me.avatar,
                        online: online,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Шапка колонки: высота 56, линия снизу.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.child, this.padX = YlSpace.s4});

  final Widget child;
  final double padX;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Container(
      height: YlPending.headerH,
      padding: EdgeInsets.symmetric(horizontal: padX),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.bg400)),
      ),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}
