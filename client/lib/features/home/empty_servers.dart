import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/icons/yl_icon.dart';
import '../../ui/illustrations/quiet_stone.dart';
import '../../ui/theme/pending_tokens.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/pressable.dart';
import '../../ui/widgets/widgets.dart';

/// Команды на сервере — не переводятся.
const _installCommands = ['sudo ./ylsrv init', 'sudo systemctl enable --now ylsrv'];

/// «Здесь пока тихо» — серверов нет (EmptyServers на ПК, MobileEmpty на
/// телефоне): три карточки — приглашение, каталог, свой сервер.
class EmptyServers extends StatelessWidget {
  const EmptyServers({
    super.key,
    required this.phone,
    required this.onInvite,
    required this.onCatalog,
    required this.onOwnServer,
  });

  final bool phone;
  final VoidCallback onInvite;
  final VoidCallback onCatalog;
  final VoidCallback onOwnServer;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    final cards = [
      _Card(
        icon: YlIconData.link,
        title: l.emptyInviteTitle,
        body: l.emptyInviteBody,
        accent: true,
        onTap: onInvite,
      ),
      _Card(
        icon: YlIconData.compass,
        title: l.emptyCatalogTitle,
        body: l.emptyCatalogBody,
        onTap: onCatalog,
      ),
      _Card(
        icon: YlIconData.server,
        title: l.emptyOwnTitle,
        body: phone ? l.emptyOwnBodyPhone : l.emptyOwnBodyPc,
        onTap: onOwnServer,
      ),
    ];
    final head = [
      const Center(child: QuietStone()),
      SizedBox(height: phone ? YlSpace.s5 : YlSpace.s6),
      Text(
        l.emptyTitle,
        textAlign: TextAlign.center,
        style: (phone ? YlText.h2 : YlText.h1).copyWith(color: c.ink),
      ),
      const SizedBox(height: YlSpace.s2),
      Text(
        phone ? l.emptyBodyPhone : l.emptyBodyPc,
        textAlign: TextAlign.center,
        style: YlText.bodyLg.copyWith(color: c.muted),
      ),
      SizedBox(height: phone ? YlSpace.s5 : YlSpace.s6),
    ];
    if (phone) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          YlSpace.s4,
          YlSpace.s8 + YlSpace.s4,
          YlSpace.s4,
          YlSpace.s5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...head,
            for (final (i, card) in cards.indexed) ...[
              if (i > 0) const SizedBox(height: YlSpace.s2),
              card,
            ],
          ],
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(YlSpace.s6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: YlPending.emptyStateW),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...head,
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, card) in cards.indexed) ...[
                      if (i > 0) const SizedBox(width: YlSpace.s3),
                      Expanded(child: card),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.accent = false,
  });

  final YlIconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  /// Рамка accent — главный вариант.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: title,
      builder: (context, s) => Container(
        padding: const EdgeInsets.all(YlPending.cardPad),
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? c.bg400 : c.bg300,
          borderRadius: YlRadius.xl,
          border: Border.all(
            color: s.focused || accent ? c.accent : c.bg400,
            width: s.focused ? YlSize.focusRing : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: YlPending.iconTile,
              height: YlPending.iconTile,
              decoration: BoxDecoration(color: c.bg400, borderRadius: YlRadius.lg),
              alignment: Alignment.center,
              child: YlIcon(icon, color: c.accent, size: YlPending.iconXl),
            ),
            const SizedBox(height: YlSpace.s3),
            ExcludeSemantics(
              child: Text(title, style: YlText.title.copyWith(color: c.ink)),
            ),
            const SizedBox(height: YlSpace.s2),
            Text(
              body,
              style: YlText.label.copyWith(color: c.muted, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Каталог серверов» до фазы каталога: честно, что его пока нет.
class CatalogSoonPanel extends StatelessWidget {
  const CatalogSoonPanel({super.key, required this.onOk});

  final VoidCallback onOk;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.catalogSoonBody, style: YlText.body.copyWith(color: c.inkSoft)),
        const SizedBox(height: YlSpace.s4),
        YlButton(label: l.commonOk, onPressed: onOk, size: YlButtonSize.lg, expand: true),
      ],
    );
  }
}

/// «Свой сервер»: как поставить ylsrv (spec/server.md, «Установка»).
class OwnServerPanel extends StatelessWidget {
  const OwnServerPanel({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.ownBody, style: YlText.body.copyWith(color: c.inkSoft)),
        const SizedBox(height: YlSpace.s3),
        Container(
          padding: const EdgeInsets.all(YlSpace.s3),
          decoration: BoxDecoration(color: c.bg000, borderRadius: YlRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final cmd in _installCommands)
                Text('\$ $cmd', style: YlText.mono.copyWith(color: c.inkSoft)),
            ],
          ),
        ),
        const SizedBox(height: YlSpace.s3),
        Text(l.ownAfter, style: YlText.caption.copyWith(color: c.subtle)),
        const SizedBox(height: YlSpace.s4),
        YlButton(label: l.ownAdd, onPressed: onAdd, size: YlButtonSize.lg, expand: true),
      ],
    );
  }
}
