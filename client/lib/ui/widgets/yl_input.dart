import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/yl_theme.dart';

/// Текстовое поле с подписью сверху (docs/design/components/Input).
///
/// Необязательность пишите словами в [label]: «О себе (необязательно)».
/// Машинный ввод — адреса, коды, секретная фраза — с [mono]. С [lines] > 1 —
/// многострочное поле. [error] показывается под полем, рамка — danger-ink.
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
    this.lines = 1,
    this.maxLength,
    this.digitsOnly = false,
    this.error,
    this.autofocus = false,
    this.textInputAction,
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
  final int lines;

  /// Предел длины без счётчика под полем.
  final int? maxLength;
  final bool digitsOnly;
  final String? error;
  final bool autofocus;
  final TextInputAction? textInputAction;

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
    final multiline = widget.lines > 1;
    final border = widget.error != null
        ? c.dangerInk
        : _focus.hasFocus
        ? c.accent
        : c.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: YlText.label.copyWith(color: c.inkSoft)),
        const SizedBox(height: YlSpace.s2),
        Container(
          height: multiline ? null : YlSize.controlMd,
          padding: EdgeInsets.symmetric(
            horizontal: YlSpace.s3,
            vertical: multiline ? YlSpace.s3 : 0,
          ),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: c.bg000,
            borderRadius: YlRadius.md,
            border: Border.all(color: border),
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
              keyboardType:
                  widget.keyboardType ??
                  (widget.digitsOnly
                      ? TextInputType.number
                      : multiline
                      ? TextInputType.multiline
                      : null),
              textInputAction: widget.textInputAction,
              minLines: widget.lines,
              maxLines: widget.lines,
              autofocus: widget.autofocus,
              inputFormatters: [
                if (widget.digitsOnly) FilteringTextInputFormatter.digitsOnly,
                if (widget.maxLength != null) LengthLimitingTextInputFormatter(widget.maxLength),
              ],
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: text,
              cursorColor: c.accent,
              autocorrect: !widget.mono && !widget.obscure,
              enableSuggestions: !widget.mono && !widget.obscure,
              enableIMEPersonalizedLearning: !widget.mono && !widget.obscure,
              decoration: InputDecoration.collapsed(
                hintText: widget.placeholder,
                hintStyle: text.copyWith(color: c.muted),
              ),
            ),
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: YlSpace.s2),
          Semantics(
            liveRegion: true,
            child: Text(widget.error!, style: YlText.caption.copyWith(color: c.dangerInk)),
          ),
        ],
      ],
    );
  }
}
