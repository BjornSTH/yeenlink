import 'package:flutter/widgets.dart';

import '../../core/db/app_db.dart';
import '../../core/redact.dart';
import '../../core/servers/server_connection.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/icons/yl_icon.dart';
import '../../ui/theme/pending_tokens.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/pressable.dart';
import '../../ui/widgets/widgets.dart';

/// Рельса серверов (Main, EmptyServers на ПК; MobileApp на телефоне):
/// логотип, разделитель, серверы, «Каталог» и «Добавить сервер».
class ServerRail extends StatelessWidget {
  const ServerRail({
    super.key,
    required this.servers,
    required this.selectedId,
    required this.onSelect,
    required this.onAdd,
    required this.onCatalog,
    this.phone = false,
  });

  final List<(ServerRow, ServerConnection)> servers;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final VoidCallback onCatalog;
  final bool phone;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    final item = phone ? YlSize.controlLg : YlSize.railItem;
    final width = phone ? YlPending.railWidthPhone : YlSize.railWidth;
    final add = YlRailButton(icon: YlIconData.plus, label: l.railAdd, onTap: onAdd, size: item);
    final catalog = YlRailButton(
      icon: YlIconData.compass,
      label: l.railCatalog,
      onTap: onCatalog,
      size: item,
    );
    // На ПК с серверами «Каталог» и «Добавить» внизу (Main); без серверов и
    // на телефоне — сразу под списком (EmptyServers, MobileApp).
    final atBottom = !phone && servers.isNotEmpty;
    return Container(
      width: width,
      color: c.bg000,
      padding: const EdgeInsets.symmetric(vertical: YlSpace.s3),
      child: Column(
        children: [
          YlLogo(size: item, withName: false, semanticLabel: l.railHome),
          const SizedBox(height: YlSpace.s2),
          Container(width: YlSpace.s8, height: YlPending.railDividerH, color: c.bg400),
          const SizedBox(height: YlSpace.s2),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final (row, conn) in servers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: YlSpace.s2),
                      child: _ServerItem(
                        conn: conn,
                        width: width,
                        size: item,
                        selected: row.id == selectedId,
                        onTap: () => onSelect(row.id),
                      ),
                    ),
                  if (!atBottom) ...[add, const SizedBox(height: YlSpace.s2), catalog],
                ],
              ),
            ),
          ),
          if (atBottom) ...[catalog, const SizedBox(height: YlSpace.s2), add],
        ],
      ),
    );
  }
}

class _ServerItem extends StatelessWidget {
  const _ServerItem({
    required this.conn,
    required this.width,
    required this.size,
    required this.selected,
    required this.onTap,
  });

  final ServerConnection conn;
  final double width;
  final double size;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([conn, streamerMode]),
      builder: (context, _) {
        final name = redact(RedactKind.serverName, conn.name, L10n.of(context));
        return Pressable(
          onTap: onTap,
          semanticLabel: name,
          selected: selected,
          builder: (context, s) => SizedBox(
            width: width,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (selected || s.hovered)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: Container(
                        width: YlPending.railIndicatorW,
                        height: s.hovered && !selected
                            ? YlPending.railIndicatorH / 2
                            : YlPending.railIndicatorH,
                        decoration: BoxDecoration(
                          color: selected ? c.accent : c.inkSoft,
                          borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(YlRadius.xsPx),
                          ),
                        ),
                      ),
                    ),
                  ),
                Opacity(
                  opacity: conn.state == ConnState.failed ? YlOpacity.disabled : 1,
                  child: YlAvatar.server(name: name, size: size, squared: selected),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
