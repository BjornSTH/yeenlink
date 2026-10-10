import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/identity/identity.dart';
import '../../core/net/server_address.dart';
import '../../core/net/server_link.dart';
import '../../core/redact.dart';
import '../../core/servers/server_connection.dart';
import '../../core/servers/servers_controller.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/widgets.dart';
import 'home_parts.dart';

/// «Добавить сервер» по адресу (spec/auth.md, «Первый контакт и
/// отпечаток»): адрес → server_info → полный отпечаток ключа, сверить с
/// `ylsrv init` → вход. Адрес с `#ОТПЕЧАТОК` закрепляет ключ без вопроса.
///
/// Отдельного макета нет: окно собрано из частей AdminClaim.
class AddServerPanel extends StatefulWidget {
  const AddServerPanel({super.key, required this.servers, required this.onAdded});

  final ServersController servers;
  final void Function(ServerConnection conn) onAdded;

  @override
  State<AddServerPanel> createState() => _AddServerPanelState();
}

enum _Step { address, checking, confirm, connecting }

class _AddServerPanelState extends State<AddServerPanel> {
  final _address = TextEditingController();
  _Step _step = _Step.address;
  ServerProbe? _probe;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  String _addressError(L10n l, AddressError e) => switch (e) {
    AddressError.empty => l.addErrEmpty,
    AddressError.badScheme => l.addErrScheme,
    AddressError.badFingerprint => l.addErrFingerprint,
    AddressError.badHost || AddressError.badPort => l.addErrAddress,
  };

  Future<void> _check() async {
    final l = L10n.of(context);
    setState(() {
      _step = _Step.checking;
      _error = null;
    });
    try {
      final probe = await widget.servers.probe(_address.text);
      if (!mounted) return;
      _probe = probe;
      if (probe.pinnedByAddress) {
        await _connect();
      } else {
        setState(() => _step = _Step.confirm);
      }
    } on AddressException catch (e) {
      _back(_addressError(l, e.error));
    } on LinkException catch (e) {
      _back(linkErrorText(l, e.error));
    } on Object catch (e) {
      debugPrint('add_server probe: $e');
      _back(l.linkNotYeenLink);
    }
  }

  Future<void> _connect() async {
    final l = L10n.of(context);
    setState(() {
      _step = _Step.connecting;
      _error = null;
    });
    try {
      final conn = await widget.servers.add(_probe!);
      if (mounted) widget.onAdded(conn);
    } on LinkException catch (e) {
      _back(linkErrorText(l, e.error));
    } on Object catch (e) {
      debugPrint('add_server connect: $e');
      _back(l.linkRejected);
    }
  }

  void _back(String error) {
    if (!mounted) return;
    setState(() {
      _step = _Step.address;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    final probe = _probe;
    if ((_step == _Step.confirm || _step == _Step.connecting) && probe != null) {
      final connecting = _step == _Step.connecting;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.addConfirmBody(redact(RedactKind.serverName, probe.info.name, l)),
            style: YlText.body.copyWith(color: c.inkSoft),
          ),
          const SizedBox(height: YlSpace.s4),
          Container(
            padding: const EdgeInsets.all(YlSpace.s3),
            decoration: BoxDecoration(color: c.bg000, borderRadius: YlRadius.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.addKeyLabel, style: YlText.caption.copyWith(color: c.subtle)),
                const SizedBox(height: YlSpace.s1),
                RedactedText(
                  RedactKind.fingerprint,
                  fingerprint(probe.info.serverPub),
                  style: YlText.title.copyWith(color: c.ink, fontFamily: YlText.monoFamily),
                ),
                const SizedBox(height: YlSpace.s1),
                RedactedText(
                  RedactKind.address,
                  probe.address.authority,
                  style: YlText.monoSm.copyWith(color: c.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: YlSpace.s3),
          Text(l.addConfirmHint, style: YlText.caption.copyWith(color: c.subtle)),
          const SizedBox(height: YlSpace.s4),
          YlButton(
            label: connecting ? l.addConnecting : l.addConnect,
            onPressed: connecting ? null : _connect,
            size: YlButtonSize.lg,
            expand: true,
          ),
          const SizedBox(height: YlSpace.s2),
          YlButton(
            label: l.commonBack,
            kind: YlButtonKind.quiet,
            onPressed: connecting ? null : () => setState(() => _step = _Step.address),
            expand: true,
          ),
        ],
      );
    }
    final busy = _step != _Step.address;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.addBody, style: YlText.body.copyWith(color: c.inkSoft)),
        const SizedBox(height: YlSpace.s4),
        YlInput(
          label: l.addLabel,
          controller: _address,
          placeholder: l.addPlaceholder,
          mono: true,
          enabled: !busy,
          error: _error,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _check(),
        ),
        const SizedBox(height: YlSpace.s4),
        YlButton(
          label: busy ? l.addChecking : l.addCheck,
          onPressed: busy ? null : _check,
          size: YlButtonSize.lg,
          expand: true,
        ),
      ],
    );
  }
}
