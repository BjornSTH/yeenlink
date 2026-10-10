import 'package:flutter/widgets.dart';

import '../../core/account/account_store.dart';
import '../../core/identity/identity.dart';
import '../../core/net/server_link.dart';
import '../../core/redact.dart';
import '../../core/servers/server_connection.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/icons/yl_icon.dart';
import '../../ui/illustrations/quiet_stone.dart';
import '../../ui/theme/pending_tokens.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/widgets.dart';

/// Ширина, с которой главное окно раскладывается как на ПК: рельса,
/// каналы и чат (Main). Уже — навигация телефона (MobileApp).
const double pcMinWidth = YlSize.railWidth + YlSize.channelColumnW + YlSize.onboardingContentW;

/// С этой ширины видна колонка участников.
const double membersMinWidth = pcMinWidth + YlPending.membersColumnW;

/// Текст ошибки соединения — что случилось и что делать.
String linkErrorText(L10n l, LinkError e) => switch (e) {
  LinkError.unreachable => l.linkUnreachable,
  LinkError.notYeenLink => l.linkNotYeenLink,
  LinkError.wrongServer => l.linkWrongServer,
  LinkError.certNotSigned => l.linkCertNotSigned,
  LinkError.deviceRevoked => l.linkDeviceRevoked,
  LinkError.proto => l.linkProto,
  LinkError.rejected => l.linkRejected,
  LinkError.closed => l.linkClosed,
  LinkError.replaced => l.linkReplaced,
};

/// Название сервера для показа: через redact.
String serverTitle(BuildContext context, String name) =>
    redact(RedactKind.serverName, name, L10n.of(context));

/// Полосы над чатом: сертификат не подтверждён, переподключение, ошибка.
class ConnectionBanners extends StatelessWidget {
  const ConnectionBanners({super.key, required this.conn});

  final ServerConnection conn;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final addr = conn.address.authority;
    final banners = <Widget>[
      if (conn.state == ConnState.retrying)
        YlStatusBanner(kind: YlBannerKind.warn, message: l.connRetrying, address: addr),
      if (conn.state == ConnState.failed)
        YlStatusBanner(
          kind: YlBannerKind.err,
          message: linkErrorText(l, conn.error ?? LinkError.closed),
          actionLabel: l.connRetryNow,
          onAction: conn.retryNow,
        ),
      if (conn.state == ConnState.online && conn.unbound)
        YlStatusBanner(kind: YlBannerKind.warn, message: l.connUnbound),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: banners);
  }
}

/// Середина чата в фазе 2: подключение, «нет владельца» или «каналов нет».
class ServerPlaceholder extends StatelessWidget {
  const ServerPlaceholder({super.key, required this.conn, required this.onClaim});

  final ServerConnection conn;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    if (conn.state == ConnState.connecting) {
      return Center(
        child: Text(l.srvConnectingTitle, style: YlText.body.copyWith(color: c.muted)),
      );
    }
    // Остановились с ошибкой — всё сказано в красной полосе.
    if (conn.state == ConnState.failed) return const SizedBox.shrink();
    final noOwner = conn.state == ConnState.online && !conn.hasOwner;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(YlSpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: YlSize.onboardingContentW),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const QuietStone(),
              const SizedBox(height: YlSpace.s6),
              Text(
                noOwner ? l.srvNoOwnerTitle : l.srvNoChannelsTitle,
                textAlign: TextAlign.center,
                style: YlText.h2.copyWith(color: c.ink),
              ),
              const SizedBox(height: YlSpace.s2),
              Text(
                noOwner ? l.srvNoOwnerBody : l.srvNoChannelsBody,
                textAlign: TextAlign.center,
                style: YlText.bodyLg.copyWith(color: c.muted),
              ),
              if (noOwner) ...[
                const SizedBox(height: YlSpace.s6),
                YlButton(
                  label: l.srvNoOwnerAction,
                  icon: YlIconData.key,
                  onPressed: onClaim,
                  size: YlButtonSize.lg,
                  expand: true,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка «я» в списке участников: аватар со статусом, имя, «Это вы».
class SelfMemberRow extends StatelessWidget {
  const SelfMemberRow({
    super.key,
    required this.name,
    required this.colorIndex,
    required this.fallbackInitials,
    required this.avatar,
    required this.online,
  });

  final String? name;
  final int colorIndex;
  final String fallbackInitials;
  final ImageProvider? avatar;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: YlSpace.s2, vertical: YlSpace.s2),
      child: Row(
        children: [
          YlAvatar.user(
            name: name,
            colorIndex: colorIndex,
            fallbackInitials: fallbackInitials,
            size: YlSize.avatarSm,
            status: online ? YlStatus.online : YlStatus.offline,
            image: avatar,
            background: c.bg200,
          ),
          const SizedBox(width: YlSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? l.homeNoName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: YlText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                ),
                Text(l.srvItsYou, style: YlText.caption.copyWith(color: c.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Что показать о себе: имя из профиля, цвет и буквы аватара.
class MeInfo {
  MeInfo(LocalAccount a, L10n l, int paletteSize)
    : name = a.profile == null ? null : Profile.fromMap(a.profile!.payloadMap()).name,
      colorIndex = avatarColorIndex(a.masterPub, paletteSize),
      fp = fingerprint(a.masterPub),
      avatar = a.avatarPng == null ? null : MemoryImage(a.avatarPng!),
      _l = l;

  final String? name;
  final int colorIndex;

  /// Отпечаток главного ключа — показывать только через redact.
  final String fp;
  final ImageProvider? avatar;
  final L10n _l;

  /// Без имени — первые знаки отпечатка; в режиме стримера — ничего.
  String get fallbackInitials {
    final shown = redact(RedactKind.fingerprint, fp, _l);
    return shown == fp ? fp.substring(0, 2) : '';
  }
}
