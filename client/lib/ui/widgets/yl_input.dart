import 'package:flutter/material.dart';

import '../theme/yl_theme.dart';

/// Текстовое поле с подписью сверху (docs/design/components/Input).
///
/// Необязательность пишите словами в [label]: «О себе (необязательно)».
/// Машинный ввод — адреса, коды, секретная фраза — с [mono].
class YlInput extends StatefulWidget {
  const YlInput({
    super.key,
    required this.label,
    this.controller,
    this.placeholder,
    this.mono = false,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.obscure = false,
    this.keyboardType,
  });

  final String label;
  final TextEditingController? controller;
  final String? placeholder;
  final bool mono;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  State<YlInput> createState() => _YlInputState();
}

class _YlInputState extends State<YlInput> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final family = widget.mono ? YlText.monoFamily : YlText.sansFamily;
    final text = YlText.body.copyWith(color: c.ink, fontFamily: family);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: YlText.label.copyWith(color: c.inkSoft)),
        const SizedBox(height: YlSpace.s2),
        Container(
          height: YlSize.controlMd,
          padding: const EdgeInsets.symmetric(horizontal: YlSpace.s3),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: c.bg000,
            borderRadius: YlRadius.md,
            border: Border.all(color: _focus.hasFocus ? c.accent : c.border),
          ),
          // TextField нужен ради выделения, буфера обмена и IME; его оформление
          // полностью заменено нашим.
          child: Material(
            type: MaterialType.transparency,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              obscureText: widget.obscure,
              keyboardType: widget.keyboardType,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: text,
              cursorColor: c.accent,
              autocorrect: !widget.mono,
              enableSuggestions: !widget.mono,
              decoration: InputDecoration.collapsed(
                hintText: widget.placeholder,
                hintStyle: text.copyWith(color: c.muted),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
