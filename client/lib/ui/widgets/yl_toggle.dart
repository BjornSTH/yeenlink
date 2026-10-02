import 'package:flutter/widgets.dart';

import '../theme/yl_theme.dart';
import 'pressable.dart';

/// Переключатель для мгновенно применяемых настроек
/// (docs/design/components/Toggle). Подпись — слева в той же строке,
/// пояснение — caption в muted.
///
/// Заблокированный ([lockedReason]) — дорожка status-offline, строка на 60 %
/// и причина вместо пояснения. Не используйте для действий с последствиями
/// (бан, смена ключа) — там кнопка с подтверждением.
class YlToggle extends StatelessWidget {
  const YlToggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.lockedReason,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? description;
  final String? lockedReason;

  bool get _locked => lockedReason != null;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final hint = lockedReason ?? description;
    final enabled = !_locked && onChanged != null;
    return Opacity(
      opacity: _locked ? YlOpacity.disabled : 1,
      child: Pressable(
        onTap: enabled ? () => onChanged!(!value) : null,
        button: false,
        toggled: value,
        semanticLabel: label,
        builder: (context, s) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: YlText.body.copyWith(color: c.ink, fontWeight: FontWeight.w600),
                  ),
                  if (hint != null) Text(hint, style: YlText.caption.copyWith(color: c.muted)),
                ],
              ),
            ),
            const SizedBox(width: YlSpace.s3),
            _Track(on: value, locked: _locked, focused: s.focused),
          ],
        ),
      ),
    );
  }
}

class _Track extends StatelessWidget {
  const _Track({required this.on, required this.locked, required this.focused});

  final bool on;
  final bool locked;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final track = locked ? c.statusOffline : (on ? c.accent : c.border);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: YlSize.toggleW,
      height: YlSize.toggleH,
      padding: const EdgeInsets.all(YlSize.toggleInset),
      decoration: BoxDecoration(color: track, borderRadius: YlRadius.full),
      foregroundDecoration: focused
          ? BoxDecoration(
              borderRadius: YlRadius.full,
              border: Border.all(color: c.ink, width: YlSize.focusRing),
            )
          : null,
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: on ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: YlSize.toggleKnob,
          height: YlSize.toggleKnob,
          decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
