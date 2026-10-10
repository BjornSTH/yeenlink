import 'package:flutter/widgets.dart';

import '../../core/account/account_store.dart';
import '../../core/identity/identity.dart';
import '../../core/vault/master_lock.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/yl_theme.dart';
import '../../ui/widgets/widgets.dart';
import '../onboarding/onboarding_controller.dart';

/// PIN-код, чтобы подписать список устройств главным ключом: нужен один
/// раз — когда этого устройства нет в списке (spec/auth.md). Закрывается
/// с [Identity] или null («Не сейчас»).
class PinPromptPanel extends StatefulWidget {
  const PinPromptPanel({super.key, required this.store, required this.onResult});

  final AccountStore store;
  final void Function(Identity? identity) onResult;

  @override
  State<PinPromptPanel> createState() => _PinPromptPanelState();
}

class _PinPromptPanelState extends State<PinPromptPanel> {
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final l = L10n.of(context);
    if (_pin.text.length != OnboardingController.pinLength || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = await widget.store.unlock(_pin.text);
      if (mounted) widget.onResult(id);
      return;
    } on WrongSecret {
      _error = l.pinWrong;
    } on PinWait catch (e) {
      _error = l.pinWait(e.left.inSeconds + 1);
    }
    _pin.clear();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.pinBody, style: YlText.body.copyWith(color: c.inkSoft)),
        const SizedBox(height: YlSpace.s4),
        YlInput(
          label: l.pinLabel,
          controller: _pin,
          obscure: true,
          digitsOnly: true,
          maxLength: OnboardingController.pinLength,
          keyboardType: TextInputType.number,
          enabled: !_busy,
          error: _error,
          autofocus: true,
          onChanged: (v) {
            if (v.length == OnboardingController.pinLength) _confirm();
          },
          onSubmitted: (_) => _confirm(),
        ),
        const SizedBox(height: YlSpace.s4),
        YlButton(
          label: l.pinConfirm,
          onPressed: _busy ? null : _confirm,
          size: YlButtonSize.lg,
          expand: true,
        ),
        const SizedBox(height: YlSpace.s2),
        YlButton(
          label: l.pinLater,
          kind: YlButtonKind.quiet,
          onPressed: _busy ? null : () => widget.onResult(null),
          expand: true,
        ),
      ],
    );
  }
}
