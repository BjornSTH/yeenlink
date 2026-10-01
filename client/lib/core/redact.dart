import 'package:flutter/widgets.dart';

import '../l10n/gen/app_localizations.dart';

/// Что за идентификатор показывается. Всё это прячет режим стримера
/// (docs/spec.md, «Режим стримера»).
enum RedactKind { serverName, address, invite, fingerprint, handle }

/// Включён ли режим стримера. Автовключение по OBS и горячая клавиша — фаза 7.
final ValueNotifier<bool> streamerMode = ValueNotifier<bool>(false);

/// Единственный путь вывода идентификаторов в интерфейс. В режиме стримера
/// текст заменяется заглушкой фиксированной длины, а не размывается: размытый
/// текст известного шрифта иногда удаётся восстановить.
String redact(RedactKind kind, String value, L10n l10n, {bool? enabled}) {
  if (!(enabled ?? streamerMode.value)) return value;
  return switch (kind) {
    RedactKind.serverName => l10n.redactedServerName,
    RedactKind.address ||
    RedactKind.invite ||
    RedactKind.fingerprint ||
    RedactKind.handle => l10n.redactedHidden,
  };
}

/// Текст идентификатора, который сам перерисовывается при смене режима.
class RedactedText extends StatelessWidget {
  const RedactedText(this.kind, this.value, {super.key, this.style, this.overflow});

  final RedactKind kind;
  final String value;
  final TextStyle? style;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: streamerMode,
      builder: (context, on, _) => Text(
        redact(kind, value, L10n.of(context), enabled: on),
        style: style,
        overflow: overflow,
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
