import 'package:flutter/widgets.dart';

import '../icons/yl_icon.dart';
import '../theme/yl_theme.dart';
import 'pressable.dart';

/// Галочка с подписью справа: квадрат radius-xs (tokens: checkbox); отмечено —
/// заливка accent и галочка on-accent. Нажимается вся строка.
class YlCheckbox extends StatelessWidget {
  const YlCheckbox({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    return Pressable(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      button: false,
      toggled: value,
      semanticLabel: label,
      builder: (context, s) => Row(
        children: [
          Container(
            width: YlSize.checkbox,
            height: YlSize.checkbox,
            decoration: BoxDecoration(
              color: value ? c.accent : c.bg000,
              borderRadius: YlRadius.xs,
              border: value ? null : Border.all(color: s.hovered ? c.accent : c.borderStrong),
            ),
            foregroundDecoration: s.focused
                ? BoxDecoration(
                    borderRadius: YlRadius.xs,
                    border: Border.all(color: c.ink, width: YlSize.focusRing),
                  )
                : null,
            child: value
                ? Center(
                    child: YlIcon(
                      YlIconData.check,
                      color: c.onAccent,
                      size: YlSize.iconSm - YlSpace.s1,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: YlSpace.s3),
          Expanded(
            child: Text(label, style: YlText.body.copyWith(color: c.ink)),
          ),
        ],
      ),
    );
  }
}
