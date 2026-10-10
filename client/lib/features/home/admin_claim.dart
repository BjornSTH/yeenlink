import 'package:flutter/widgets.dart';

import '../../core/net/server_link.dart';
import '../../core/protocol/handshake.dart';
import '../../core/redact.dart';
import '../../core/servers/server_connection.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/icons/yl_icon.dart';
import '../../ui/theme/pending_tokens.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/widgets.dart';

/// Команда на сервере — не переводится.
const _adminTokenCommand = r'$ ylsrv admin-token';
const _tokenPlaceholder = 'ylat_…';
final _tokenFormat = RegExp(r'^ylat_[0-9A-Za-z]{43}$');

/// «Стать владельцем сервера» (AdminClaim, AdminClaimPhone): ключ
/// администратора → admin.claim. Состояния: ввод, «Проверяю ключ…», ошибка,
/// «Готово».
class AdminClaimPanel extends StatefulWidget {
  const AdminClaimPanel({
    super.key,
    required this.conn,
    required this.myFingerprint,
    required this.onDone,
  });

  final ServerConnection conn;

  /// Отпечаток моего главного ключа (короткий) — через redact.
  final String myFingerprint;
  final VoidCallback onDone;

  @override
  State<AdminClaimPanel> createState() => _AdminClaimPanelState();
}

enum _Phase { idle, checking, done }

class _AdminClaimPanelState extends State<AdminClaimPanel> {
  final _token = TextEditingController();
  _Phase _phase = _Phase.idle;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    final l = L10n.of(context);
    final token = _token.text.trim();
    if (!_tokenFormat.hasMatch(token)) {
      setState(() => _error = l.claimErrFormat);
      return;
    }
    setState(() {
      _phase = _Phase.checking;
      _error = null;
    });
    String? error;
    try {
      await widget.conn.claimOwner(token);
    } on ServerError catch (e) {
      error = switch (e.code) {
        ErrCode.rateLimited => l.claimErrRate,
        ErrCode.badToken => l.claimErrBadToken,
        _ => l.linkRejected,
      };
    } on LinkException {
      error = l.claimErrOffline;
    }
    if (!mounted) return;
    setState(() {
      _phase = error == null ? _Phase.done : _Phase.idle;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    final server = redact(RedactKind.serverName, widget.conn.name, l);
    if (_phase == _Phase.done) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: YlPending.doneMark,
                height: YlPending.doneMark,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.bg400,
                  border: Border.all(color: c.accent, width: YlSize.focusRing),
                ),
                alignment: Alignment.center,
                child: YlIcon(YlIconData.check, color: c.accent, size: YlPending.doneMarkIcon),
              ),
              const SizedBox(width: YlSpace.s3),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(l.claimDone(server), style: YlText.bodyLg.copyWith(color: c.inkSoft)),
                ),
              ),
            ],
          ),
          const SizedBox(height: YlSpace.s4),
          YlButton(
            label: l.claimDoneButton,
            onPressed: widget.onDone,
            size: YlButtonSize.lg,
            expand: true,
          ),
        ],
      );
    }
    final checking = _phase == _Phase.checking;
    // Отпечаток внутри фразы — моноширинным; фраза целиком из локализации.
    const mark = '\u0000';
    final note = l.claimNote(mark).split(mark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.claimBody(server), style: YlText.body.copyWith(color: c.inkSoft)),
        const SizedBox(height: YlSpace.s4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: YlSpace.s3, vertical: YlSpace.s3),
          decoration: BoxDecoration(color: c.bg000, borderRadius: YlRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.claimLostKey, style: YlText.caption.copyWith(color: c.subtle)),
              const SizedBox(height: YlSpace.s1),
              Text(_adminTokenCommand, style: YlText.mono.copyWith(color: c.inkSoft)),
              const SizedBox(height: YlSpace.s1),
              Text(l.claimConsoleProof, style: YlText.caption.copyWith(color: c.subtle)),
            ],
          ),
        ),
        const SizedBox(height: YlSpace.s4),
        YlInput(
          label: l.claimLabel,
          controller: _token,
          placeholder: _tokenPlaceholder,
          mono: true,
          lines: 3,
          enabled: !checking,
          error: _error,
          autofocus: true,
          onSubmitted: (_) => _claim(),
        ),
        const SizedBox(height: YlSpace.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YlIcon(YlIconData.shield, color: c.statusOnline, size: YlSize.iconSm),
            const SizedBox(width: YlSpace.s2),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: streamerMode,
                builder: (context, on, _) => Text.rich(
                  TextSpan(
                    style: YlText.caption.copyWith(color: c.subtle),
                    children: [
                      TextSpan(text: note.first),
                      TextSpan(
                        text: redact(RedactKind.fingerprint, widget.myFingerprint, l, enabled: on),
                        style: YlText.monoSm.copyWith(color: c.inkSoft),
                      ),
                      if (note.length > 1) TextSpan(text: note[1]),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: YlSpace.s4),
        YlButton(
          label: checking ? l.claimChecking : l.claimButton,
          onPressed: checking ? null : _claim,
          size: YlButtonSize.lg,
          expand: true,
        ),
      ],
    );
  }
}
