import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/account/account_store.dart';
import '../../core/identity/identity.dart';
import '../../core/servers/server_connection.dart';
import '../../core/servers/servers_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/widgets.dart';
import 'add_server.dart';
import 'admin_claim.dart';
import 'empty_servers.dart';
import 'home_controller.dart';
import 'home_parts.dart';
import 'pc_shell.dart';
import 'phone_shell.dart';
import 'pin_prompt.dart';
import 'profile_view.dart';
import 'rail.dart';

/// Главное окно: на ПК — рельса, каналы, чат и участники (Main), на
/// телефоне — нижняя навигация (MobileApp). Без серверов — «Здесь пока тихо».
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final HomeController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PhoneTab _tab = PhoneTab.servers;
  bool _phone = false;

  HomeController get _home => widget.controller;

  @override
  void initState() {
    super.initState();
    _home.askPin = _askPin;
    if (!_home.started) unawaited(_home.start());
  }

  @override
  void dispose() {
    if (_home.askPin == _askPin) _home.askPin = null;
    super.dispose();
  }

  Future<T?> _modal<T>(String title, Widget Function(BuildContext ctx) body) {
    final l = L10n.of(context);
    return showYlModal<T>(
      context,
      title: title,
      closeLabel: _phone ? l.commonBack : l.commonClose,
      phone: _phone,
      builder: body,
    );
  }

  Future<Identity?> _askPin() async {
    if (!mounted) return null;
    return _modal<Identity>(
      L10n.of(context).pinTitle,
      (ctx) => PinPromptPanel(store: _home.store, onResult: (id) => Navigator.of(ctx).pop(id)),
    );
  }

  void _addServer() {
    unawaited(
      _modal<ServerConnection>(
        L10n.of(context).addTitle,
        (ctx) =>
            AddServerPanel(servers: _home.servers, onAdded: (conn) => Navigator.of(ctx).pop(conn)),
      ).then((conn) {
        // Только что поставленный сервер без владельца — сразу предложить ключ.
        if (conn != null && mounted && conn.state == ConnState.online && !conn.hasOwner) {
          _claim(conn);
        }
      }),
    );
  }

  void _claim(ServerConnection conn) {
    final l = L10n.of(context);
    unawaited(
      _modal<void>(
        _phone ? l.claimTitlePhone : l.claimTitle,
        (ctx) => AdminClaimPanel(
          conn: conn,
          myFingerprint: shortFingerprint(_home.account.value.masterPub),
          onDone: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _catalog() {
    unawaited(
      _modal<void>(
        L10n.of(context).catalogSoonTitle,
        (ctx) => CatalogSoonPanel(onOk: () => Navigator.of(ctx).pop()),
      ),
    );
  }

  void _ownServer() {
    unawaited(
      _modal<bool>(
        L10n.of(context).ownTitle,
        (ctx) => OwnServerPanel(onAdd: () => Navigator.of(ctx).pop(true)),
      ).then((add) {
        if (add == true && mounted) _addServer();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YlSurface(
      child: ListenableBuilder(
        listenable: _home,
        builder: (context, _) {
          if (!_home.started) return const SizedBox.shrink();
          return ListenableBuilder(
            listenable: Listenable.merge([_home.servers, _home.account]),
            builder: (context, _) => LayoutBuilder(
              builder: (context, box) {
                _phone = box.maxWidth < pcMinWidth;
                final servers = _home.servers;
                if (!servers.loaded) return const SizedBox.shrink();
                return _phone
                    ? _phoneLayout(servers, _home.account.value)
                    : _pcLayout(servers, _home.account.value, box.maxWidth);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _rail(ServersController servers, {required bool phone}) => ServerRail(
    servers: servers.servers,
    selectedId: servers.selected?.$1.id,
    onSelect: servers.select,
    onAdd: _addServer,
    onCatalog: _catalog,
    phone: phone,
  );

  Widget _pcLayout(ServersController servers, LocalAccount account, double width) {
    final sel = servers.selected;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rail(servers, phone: false),
        if (sel == null)
          Expanded(
            child: EmptyServers(
              phone: false,
              onInvite: _addServer,
              onCatalog: _catalog,
              onOwnServer: _ownServer,
            ),
          )
        else ...[
          ChannelColumn(conn: sel.$2, account: account),
          Expanded(
            child: ChatArea(conn: sel.$2, onClaim: () => _claim(sel.$2)),
          ),
          if (width >= membersMinWidth) MembersColumn(conn: sel.$2, account: account),
        ],
      ],
    );
  }

  Widget _phoneLayout(ServersController servers, LocalAccount account) {
    final l = L10n.of(context);
    final sel = servers.selected;
    final body = switch (_tab) {
      PhoneTab.servers when sel == null => EmptyServers(
        phone: true,
        onInvite: _addServer,
        onCatalog: _catalog,
        onOwnServer: _ownServer,
      ),
      PhoneTab.servers => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rail(servers, phone: true),
          Expanded(
            child: PhoneServerPanel(conn: sel!.$2, onClaim: () => _claim(sel.$2)),
          ),
        ],
      ),
      PhoneTab.feed => PhoneTabPlaceholder(title: l.feedEmptyTitle, body: l.feedEmptyBody),
      PhoneTab.dms => PhoneTabPlaceholder(title: l.dmsEmptyTitle, body: l.dmsEmptyBody),
      PhoneTab.profile => ProfileView(account: account),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: SafeArea(bottom: false, child: body)),
        PhoneNavBar(tab: _tab, onTab: (t) => setState(() => _tab = t)),
      ],
    );
  }
}
