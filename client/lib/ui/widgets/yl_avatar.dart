import 'package:flutter/widgets.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme/yl_theme.dart';

/// Статус участника. Цвет точки различается и светлотой, а рядом в списках
/// всегда есть текст (design/README.md).
enum YlStatus { online, idle, dnd, offline }

extension YlStatusLabel on YlStatus {
  String label(L10n l10n) => switch (this) {
    YlStatus.online => l10n.statusOnline,
    YlStatus.idle => l10n.statusIdle,
    YlStatus.dnd => l10n.statusDnd,
    YlStatus.offline => l10n.statusOffline,
  };

  Color color(YlColors c) => switch (this) {
    YlStatus.online => c.statusOnline,
    YlStatus.idle => c.statusIdle,
    YlStatus.dnd => c.statusDnd,
    YlStatus.offline => c.statusOffline,
  };
}

/// Аватар пользователя или сервера (docs/design/components/Avatar).
///
/// Без картинки — две буквы (800, on-accent) на приглушённом тёплом фоне,
/// который выбирается по имени и не меняется от запуска к запуску.
class YlAvatar extends StatelessWidget {
  /// Круглый аватар пользователя: точка статуса снизу справа, двойное кольцо,
  /// пока человек говорит в голосовом.
  const YlAvatar.user({
    super.key,
    required this.name,
    this.size = YlSize.avatarMd,
    this.status,
    this.speaking = false,
    this.image,
    this.background,
  }) : server = false,
       squared = false;

  /// Сервер: фон hyena-banner, текст ink. В рельсе активный — квадрат
  /// со скруглением radius-lg ([squared]), остальные круглые.
  const YlAvatar.server({
    super.key,
    required this.name,
    this.size = YlSize.railItem,
    this.squared = true,
    this.image,
  }) : server = true,
       status = null,
       speaking = false,
       background = null;

  final String name;
  final double size;
  final YlStatus? status;
  final bool speaking;
  final ImageProvider? image;
  final bool server;
  final bool squared;

  /// Цвет фона под аватаром — им обводятся точка статуса и кольцо.
  /// По умолчанию bg-100.
  final Color? background;

  /// Две буквы: первые буквы двух слов или первые две буквы одного.
  static String initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    final runes = words.length > 1
        ? [words[0].runes.first, words[1].runes.first]
        : words[0].runes.take(2).toList();
    return String.fromCharCodes(runes).toUpperCase();
  }

  static Color _fill(YlColors c, String name) {
    final palette = c.avatarPalette;
    final hash = name.runes.fold<int>(0, (h, r) => (h * 31 + r) & 0x7fffffff);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final c = YlColors.of(context);
    final under = background ?? c.bg100;
    final shape = squared
        ? const BoxDecoration(borderRadius: YlRadius.lg)
        : const BoxDecoration(shape: BoxShape.circle);

    Widget face = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: shape.copyWith(
        color: server ? c.hyenaBanner : _fill(c, name),
        image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
        // Кольцо говорящего: зазор цветом фона, затем accent (Avatar/preview).
        boxShadow: speaking
            ? [
                BoxShadow(color: c.accent, spreadRadius: 2 * YlSize.avatarRing),
                BoxShadow(color: under, spreadRadius: YlSize.avatarRing),
              ]
            : null,
      ),
      child: image != null
          ? null
          : Text(
              initials(name),
              // Размер букв — треть стороны, как в превью (40 → 13, 44 → 14).
              style: YlText.label.copyWith(
                fontSize: (size * 0.32).roundToDouble(),
                fontWeight: FontWeight.w800,
                height: 1,
                color: server ? c.ink : c.onAccent,
              ),
            ),
    );

    final st = status;
    if (st != null) {
      const dotOuter = YlSize.statusDot + 2 * YlSize.avatarDotBorder;
      face = Stack(
        clipBehavior: Clip.none,
        children: [
          face,
          Positioned(
            right: YlSize.avatarDotOffset,
            bottom: YlSize.avatarDotOffset,
            child: Container(
              width: dotOuter,
              height: dotOuter,
              decoration: BoxDecoration(
                color: st.color(c),
                shape: BoxShape.circle,
                border: Border.all(color: under, width: YlSize.avatarDotBorder),
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      label: st == null ? name : '$name, ${st.label(L10n.of(context))}',
      image: true,
      child: ExcludeSemantics(child: face),
    );
  }
}
