import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Состояние нажимаемого элемента.
typedef PressState = ({bool hovered, bool pressed, bool focused, bool enabled});

/// Общая основа нажимаемых виджетов: мышь, касание, фокус с клавиатуры и
/// активация Enter/пробелом — без Material-эффектов вроде «волны».
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.semanticLabel,
    this.button = true,
    this.toggled,
    this.selected,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, PressState state) builder;
  final String? semanticLabel;
  final bool button;
  final bool? toggled;
  final bool? selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final state = (hovered: _hovered, pressed: _pressed, focused: _focused, enabled: _enabled);
    return Semantics(
      button: widget.button,
      enabled: _enabled,
      toggled: widget.toggled,
      selected: widget.selected,
      label: widget.semanticLabel,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: _enabled,
        mouseCursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onTap,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          child: widget.builder(context, state),
        ),
      ),
    );
  }
}
