// СГЕНЕРИРОВАНО tool/gen_tokens.dart из docs/design/tokens.json
// и docs/design/tokens.local.json (временно). Не править руками.

import 'package:flutter/material.dart' show Theme, ThemeExtension;
import 'package:flutter/widgets.dart';

/// Цвета темы. Получение: `YlColors.of(context)`.
@immutable
class YlColors extends ThemeExtension<YlColors> {
  const YlColors({
    required this.bg000,
    required this.bg100,
    required this.bg200,
    required this.bg300,
    required this.bg400,
    required this.border,
    required this.borderStrong,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.subtle,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentAltTerracotta,
    required this.accentAltTeal,
    required this.statusOnline,
    required this.statusIdle,
    required this.statusDnd,
    required this.statusOffline,
    required this.danger,
    required this.onDanger,
    required this.dangerInk,
    required this.warnBg,
    required this.warnBorder,
    required this.warnInk,
    required this.okBg,
    required this.okBorder,
    required this.okInk,
    required this.errBg,
    required this.errBorder,
    required this.errInk,
    required this.roleMaster,
    required this.rolePlayer,
    required this.roleGuest,
    required this.roleBot,
    required this.hyenaBanner,
    required this.hyenaSpot,
    required this.scrim,
    required this.avatar1,
    required this.avatar2,
    required this.avatar3,
    required this.avatar4,
  });

  /// Самый глубокий фон: рельса серверов, нижняя навигация, поля ввода внутри карточек.
  final Color bg000;

  /// Основной фон окна и экранов. Текст ink и muted стоят на нём.
  final Color bg100;

  /// Боковые колонки: каналы, участники, панель профиля, лист на телефоне.
  final Color bg200;

  /// Карточки, группы настроек, плитки, поле сообщения.
  final Color bg300;

  /// Выбранная строка канала, активная вкладка сегмента, нажатое состояние.
  final Color bg400;

  /// Тонкие границы карточек, полей и неактивных кнопок.
  final Color border;

  /// Пунктир «добавить», рамка радиокнопки, разделители повыше.
  final Color borderStrong;

  /// Основной текст и иконки на bg-100…bg-400.
  final Color ink;

  /// Текст второго плана: описание сервера, «о себе», подписи полей.
  final Color inkSoft;

  /// Подписи, время, неактивные иконки. 4.5:1 на bg-100.
  final Color muted;

  /// Надписи-оверлайны (ТЕКСТОВЫЕ, РОЛИ), метки времени. Только мелкий служебный текст.
  final Color subtle;

  /// Охра гиены: заливка главных кнопок, активный индикатор, кольцо говорящего. На заливке — on-accent.
  final Color accent;

  /// Акцент как ТЕКСТ на фоне: имя Мастера, ссылки «управлять».
  final Color accentInk;

  /// Текст и иконки на заливке accent.
  final Color onAccent;

  /// Альтернативный акцент из настроек «Внешний вид».
  final Color accentAltTerracotta;

  /// Альтернативный акцент из настроек «Внешний вид».
  final Color accentAltTeal;

  /// Точка «в сети», «Голос подключён», таймер канала.
  final Color statusOnline;

  /// Точка «отошёл».
  final Color statusIdle;

  /// Точка «не беспокоить», выключенный микрофон.
  final Color statusDnd;

  /// Точка «не в сети».
  final Color statusOffline;

  /// Заливка кнопки «Покинуть канал». На ней — on-danger.
  final Color danger;

  /// Иконка на заливке danger.
  final Color onDanger;

  /// Опасные действия текстом: «Отвязать», «Выйти из профиля», «Опасная зона».
  final Color dangerInk;

  /// Фон янтарной полосы «переподключаюсь», предупреждения о секретной фразе.
  final Color warnBg;

  /// Граница янтарной полосы.
  final Color warnBorder;

  /// Текст янтарной полосы.
  final Color warnInk;

  /// Фон зелёных блоков: «ключ совпадает», «сервер работает».
  final Color okBg;

  /// Граница зелёных блоков.
  final Color okBorder;

  /// Текст зелёных блоков.
  final Color okInk;

  /// Фон красной полосы «сервер недоступен».
  final Color errBg;

  /// Граница красной полосы, рамка кнопок в ней.
  final Color errBorder;

  /// Текст красной полосы.
  final Color errInk;

  /// Цвет роли Мастер: точка в чипе и имя в списке.
  final Color roleMaster;

  /// Цвет роли Игрок.
  final Color rolePlayer;

  /// Цвет роли Гость.
  final Color roleGuest;

  /// Цвет роли Бот.
  final Color roleBot;

  /// Фон баннера по умолчанию — шерсть гиены.
  final Color hyenaBanner;

  /// Пятна на баннере по умолчанию.
  final Color hyenaSpot;

  /// Затемнение под модальными окнами и нижним листом.
  final Color scrim;

  /// Фон аватара без картинки (инициалы on-accent). Avatar/preview.html.
  final Color avatar1;

  /// Фон аватара без картинки.
  final Color avatar2;

  /// Фон аватара без картинки.
  final Color avatar3;

  /// Фон аватара без картинки.
  final Color avatar4;

  static const YlColors dark = YlColors(
    bg000: Color(0xFF151412),
    bg100: Color(0xFF1C1B19),
    bg200: Color(0xFF201E1C),
    bg300: Color(0xFF24221F),
    bg400: Color(0xFF2D2A26),
    border: Color(0xFF3A3631),
    borderStrong: Color(0xFF4A443D),
    ink: Color(0xFFECE6DD),
    inkSoft: Color(0xFFCFC7BC),
    muted: Color(0xFFA39A8D),
    subtle: Color(0xFF918A7E),
    accent: Color(0xFFC9A06B),
    accentInk: Color(0xFFD4AE7C),
    onAccent: Color(0xFF1C1B19),
    accentAltTerracotta: Color(0xFFD97A4A),
    accentAltTeal: Color(0xFF5FA8A0),
    statusOnline: Color(0xFF8BAA7A),
    statusIdle: Color(0xFFD9A55B),
    statusDnd: Color(0xFFC26B5A),
    statusOffline: Color(0xFF5E5850),
    danger: Color(0xFFA9493E),
    onDanger: Color(0xFFF3ECE4),
    dangerInk: Color(0xFFD98C7A),
    warnBg: Color(0xFF2A2119),
    warnBorder: Color(0xFF5A4128),
    warnInk: Color(0xFFE8D9C2),
    okBg: Color(0xFF1F261C),
    okBorder: Color(0xFF3A4A33),
    okInk: Color(0xFFDCE8D3),
    errBg: Color(0xFF2B1D1A),
    errBorder: Color(0xFF6A3A31),
    errInk: Color(0xFFEBCFC8),
    roleMaster: Color(0xFFE0B26A),
    rolePlayer: Color(0xFF9DB58A),
    roleGuest: Color(0xFFA9A0C9),
    roleBot: Color(0xFF7FA9B5),
    hyenaBanner: Color(0xFF3A3026),
    hyenaSpot: Color(0xFF4E3E2D),
    scrim: Color(0xAD0F0E0D),
    avatar1: Color(0xFF8A6E4B),
    avatar2: Color(0xFF6E7A63),
    avatar3: Color(0xFF9A8566),
    avatar4: Color(0xFF7D6A7A),
  );

  static const YlColors light = YlColors(
    bg000: Color(0xFFE9E3DA),
    bg100: Color(0xFFF4F0EA),
    bg200: Color(0xFFEDE7DE),
    bg300: Color(0xFFFBF8F3),
    bg400: Color(0xFFE3DCD1),
    border: Color(0xFFD6CEC2),
    borderStrong: Color(0xFFBFB5A7),
    ink: Color(0xFF2A2622),
    inkSoft: Color(0xFF4A443D),
    muted: Color(0xFF6B6258),
    subtle: Color(0xFF6E655B),
    accent: Color(0xFFC9A06B),
    accentInk: Color(0xFF86602F),
    onAccent: Color(0xFF1C1B19),
    accentAltTerracotta: Color(0xFFD97A4A),
    accentAltTeal: Color(0xFF5FA8A0),
    statusOnline: Color(0xFF466E37),
    statusIdle: Color(0xFFA8752A),
    statusDnd: Color(0xFFA34E3E),
    statusOffline: Color(0xFFA39A8D),
    danger: Color(0xFFA9493E),
    onDanger: Color(0xFFF3ECE4),
    dangerInk: Color(0xFFA34E3E),
    warnBg: Color(0xFFF6EAD6),
    warnBorder: Color(0xFFE0C597),
    warnInk: Color(0xFF6B4A1C),
    okBg: Color(0xFFE6EFE0),
    okBorder: Color(0xFFBFD3B2),
    okInk: Color(0xFF2F4A23),
    errBg: Color(0xFFF6E3DE),
    errBorder: Color(0xFFE2B3A8),
    errInk: Color(0xFF7A2E22),
    roleMaster: Color(0xFF7A561F),
    rolePlayer: Color(0xFF436B35),
    roleGuest: Color(0xFF5E5488),
    roleBot: Color(0xFF3A6874),
    hyenaBanner: Color(0xFFE3D3BC),
    hyenaSpot: Color(0xFFCDB596),
    scrim: Color(0x732A2622),
    avatar1: Color(0xFF8A6E4B),
    avatar2: Color(0xFF6E7A63),
    avatar3: Color(0xFF9A8566),
    avatar4: Color(0xFF7D6A7A),
  );

  static YlColors of(BuildContext context) => _ylExtension<YlColors>(context);

  @override
  YlColors copyWith({
    Color? bg000,
    Color? bg100,
    Color? bg200,
    Color? bg300,
    Color? bg400,
    Color? border,
    Color? borderStrong,
    Color? ink,
    Color? inkSoft,
    Color? muted,
    Color? subtle,
    Color? accent,
    Color? accentInk,
    Color? onAccent,
    Color? accentAltTerracotta,
    Color? accentAltTeal,
    Color? statusOnline,
    Color? statusIdle,
    Color? statusDnd,
    Color? statusOffline,
    Color? danger,
    Color? onDanger,
    Color? dangerInk,
    Color? warnBg,
    Color? warnBorder,
    Color? warnInk,
    Color? okBg,
    Color? okBorder,
    Color? okInk,
    Color? errBg,
    Color? errBorder,
    Color? errInk,
    Color? roleMaster,
    Color? rolePlayer,
    Color? roleGuest,
    Color? roleBot,
    Color? hyenaBanner,
    Color? hyenaSpot,
    Color? scrim,
    Color? avatar1,
    Color? avatar2,
    Color? avatar3,
    Color? avatar4,
  }) => YlColors(
    bg000: bg000 ?? this.bg000,
    bg100: bg100 ?? this.bg100,
    bg200: bg200 ?? this.bg200,
    bg300: bg300 ?? this.bg300,
    bg400: bg400 ?? this.bg400,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    ink: ink ?? this.ink,
    inkSoft: inkSoft ?? this.inkSoft,
    muted: muted ?? this.muted,
    subtle: subtle ?? this.subtle,
    accent: accent ?? this.accent,
    accentInk: accentInk ?? this.accentInk,
    onAccent: onAccent ?? this.onAccent,
    accentAltTerracotta: accentAltTerracotta ?? this.accentAltTerracotta,
    accentAltTeal: accentAltTeal ?? this.accentAltTeal,
    statusOnline: statusOnline ?? this.statusOnline,
    statusIdle: statusIdle ?? this.statusIdle,
    statusDnd: statusDnd ?? this.statusDnd,
    statusOffline: statusOffline ?? this.statusOffline,
    danger: danger ?? this.danger,
    onDanger: onDanger ?? this.onDanger,
    dangerInk: dangerInk ?? this.dangerInk,
    warnBg: warnBg ?? this.warnBg,
    warnBorder: warnBorder ?? this.warnBorder,
    warnInk: warnInk ?? this.warnInk,
    okBg: okBg ?? this.okBg,
    okBorder: okBorder ?? this.okBorder,
    okInk: okInk ?? this.okInk,
    errBg: errBg ?? this.errBg,
    errBorder: errBorder ?? this.errBorder,
    errInk: errInk ?? this.errInk,
    roleMaster: roleMaster ?? this.roleMaster,
    rolePlayer: rolePlayer ?? this.rolePlayer,
    roleGuest: roleGuest ?? this.roleGuest,
    roleBot: roleBot ?? this.roleBot,
    hyenaBanner: hyenaBanner ?? this.hyenaBanner,
    hyenaSpot: hyenaSpot ?? this.hyenaSpot,
    scrim: scrim ?? this.scrim,
    avatar1: avatar1 ?? this.avatar1,
    avatar2: avatar2 ?? this.avatar2,
    avatar3: avatar3 ?? this.avatar3,
    avatar4: avatar4 ?? this.avatar4,
  );

  @override
  YlColors lerp(YlColors? other, double t) {
    if (other == null) return this;
    return YlColors(
      bg000: Color.lerp(bg000, other.bg000, t)!,
      bg100: Color.lerp(bg100, other.bg100, t)!,
      bg200: Color.lerp(bg200, other.bg200, t)!,
      bg300: Color.lerp(bg300, other.bg300, t)!,
      bg400: Color.lerp(bg400, other.bg400, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentAltTerracotta: Color.lerp(accentAltTerracotta, other.accentAltTerracotta, t)!,
      accentAltTeal: Color.lerp(accentAltTeal, other.accentAltTeal, t)!,
      statusOnline: Color.lerp(statusOnline, other.statusOnline, t)!,
      statusIdle: Color.lerp(statusIdle, other.statusIdle, t)!,
      statusDnd: Color.lerp(statusDnd, other.statusDnd, t)!,
      statusOffline: Color.lerp(statusOffline, other.statusOffline, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      onDanger: Color.lerp(onDanger, other.onDanger, t)!,
      dangerInk: Color.lerp(dangerInk, other.dangerInk, t)!,
      warnBg: Color.lerp(warnBg, other.warnBg, t)!,
      warnBorder: Color.lerp(warnBorder, other.warnBorder, t)!,
      warnInk: Color.lerp(warnInk, other.warnInk, t)!,
      okBg: Color.lerp(okBg, other.okBg, t)!,
      okBorder: Color.lerp(okBorder, other.okBorder, t)!,
      okInk: Color.lerp(okInk, other.okInk, t)!,
      errBg: Color.lerp(errBg, other.errBg, t)!,
      errBorder: Color.lerp(errBorder, other.errBorder, t)!,
      errInk: Color.lerp(errInk, other.errInk, t)!,
      roleMaster: Color.lerp(roleMaster, other.roleMaster, t)!,
      rolePlayer: Color.lerp(rolePlayer, other.rolePlayer, t)!,
      roleGuest: Color.lerp(roleGuest, other.roleGuest, t)!,
      roleBot: Color.lerp(roleBot, other.roleBot, t)!,
      hyenaBanner: Color.lerp(hyenaBanner, other.hyenaBanner, t)!,
      hyenaSpot: Color.lerp(hyenaSpot, other.hyenaSpot, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
      avatar1: Color.lerp(avatar1, other.avatar1, t)!,
      avatar2: Color.lerp(avatar2, other.avatar2, t)!,
      avatar3: Color.lerp(avatar3, other.avatar3, t)!,
      avatar4: Color.lerp(avatar4, other.avatar4, t)!,
    );
  }
}

T _ylExtension<T extends ThemeExtension<T>>(BuildContext context) {
  final ext = Theme.of(context).extension<T>();
  assert(ext != null, 'В теме нет $T: оберните виджет в ylTheme().');
  return ext!;
}

/// Тени — только у того, что парит над экраном. `YlShadows.of(context)`.
@immutable
class YlShadows extends ThemeExtension<YlShadows> {
  const YlShadows({required this.modal, required this.popover});

  /// Модальные окна. Других теней в интерфейсе нет — глубину дают фоны bg-000…bg-400.
  final List<BoxShadow> modal;

  /// Карточка участника, выпадающие меню.
  final List<BoxShadow> popover;

  static const YlShadows dark = YlShadows(
    modal: [BoxShadow(offset: Offset(0, 30), blurRadius: 68.416, color: Color(0x80000000))],
    popover: [BoxShadow(offset: Offset(0, 18), blurRadius: 40.7032, color: Color(0x73000000))],
  );

  static const YlShadows light = YlShadows(
    modal: [BoxShadow(offset: Offset(0, 24), blurRadius: 51.0955, color: Color(0x2E3C2D1E))],
    popover: [BoxShadow(offset: Offset(0, 14), blurRadius: 30.3109, color: Color(0x293C2D1E))],
  );

  static YlShadows of(BuildContext context) => _ylExtension<YlShadows>(context);

  @override
  YlShadows copyWith({List<BoxShadow>? modal, List<BoxShadow>? popover}) =>
      YlShadows(modal: modal ?? this.modal, popover: popover ?? this.popover);

  @override
  YlShadows lerp(YlShadows? other, double t) {
    if (other == null) return this;
    return YlShadows(
      modal: BoxShadow.lerpList(modal, other.modal, t)!,
      popover: BoxShadow.lerpList(popover, other.popover, t)!,
    );
  }
}

/// Шкала текста. Цвета здесь нет — его задаёт виджет из YlColors.
abstract final class YlText {
  static const String sansFamily = 'Manrope';
  static const String monoFamily = 'JetBrains Mono';

  /// Экран первого входа на ПК.
  static const TextStyle display = TextStyle(
    fontFamily: sansFamily,
    fontSize: 44,
    height: 1.12,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.88,
  );

  /// Заголовок шага онбординга.
  static const TextStyle h1 = TextStyle(
    fontFamily: sansFamily,
    fontSize: 32,
    height: 1.15,
    fontWeight: FontWeight.w800,
  );

  /// Заголовки экранов на телефоне, модальных окон.
  static const TextStyle h2 = TextStyle(
    fontFamily: sansFamily,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w800,
  );

  /// Имя в карточке профиля, название сервера.
  static const TextStyle title = TextStyle(
    fontFamily: sansFamily,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w800,
  );

  /// Сообщения в чате на телефоне, описания.
  static const TextStyle bodyLg = TextStyle(
    fontFamily: sansFamily,
    fontSize: 15,
    height: 1.55,
    fontWeight: FontWeight.w400,
  );

  /// Сообщения на ПК, строки настроек.
  static const TextStyle body = TextStyle(
    fontFamily: sansFamily,
    fontSize: 14,
    height: 1.55,
    fontWeight: FontWeight.w400,
  );

  /// Подписи полей, кнопки второго уровня, чипы.
  static const TextStyle label = TextStyle(
    fontFamily: sansFamily,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w600,
  );

  /// Время, пояснения под строками настроек.
  static const TextStyle caption = TextStyle(
    fontFamily: sansFamily,
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  /// Заголовки групп: всегда заглавными.
  static const TextStyle overline = TextStyle(
    fontFamily: sansFamily,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.88,
  );

  /// Отпечатки ключей, адреса, порты, коды приглашений, броски кубиков.
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    fontSize: 13,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  /// Текст кнопки высоты control-lg (вторичная и тихая — 600). Button/preview.html.
  static const TextStyle button = TextStyle(
    fontFamily: sansFamily,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );

  /// Бейджи ЭФИР и БОТ. Badge/preview.html.
  static const TextStyle badge = TextStyle(
    fontFamily: sansFamily,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
  );

  /// Текст полосы состояния. StatusBanner/preview.html.
  static const TextStyle banner = TextStyle(
    fontFamily: sansFamily,
    fontSize: 13,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  /// Адрес в полосе состояния. StatusBanner/preview.html.
  static const TextStyle monoSm = TextStyle(
    fontFamily: monoFamily,
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  /// Таймер голосового канала в строке. ChannelRow/preview.html.
  static const TextStyle monoXs = TextStyle(
    fontFamily: monoFamily,
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );
}

/// Отступы, сетка 4 px.
abstract final class YlSpace {
  /// Зазор между иконкой и счётчиком, внутри сегмента.
  static const double s1 = 4;

  /// Между кнопками в ряду, между чипами.
  static const double s2 = 8;

  /// Между аватаром и текстом, плитки голосового канала.
  static const double s3 = 12;

  /// Внутренний отступ строк настроек и карточек; поля экрана на телефоне.
  static const double s4 = 16;

  /// Поля области чата на ПК.
  static const double s5 = 20;

  /// Между группами настроек, поля модальных окон.
  static const double s6 = 24;

  /// Поля содержимого больших модальных окон.
  static const double s8 = 32;
}

/// Скругления: `YlRadius.lg` — BorderRadius, `YlRadius.lgPx` — число.
abstract final class YlRadius {
  /// Бейджи ЭФИР и БОТ.
  static const double xsPx = 4;
  static const BorderRadius xs = BorderRadius.all(Radius.circular(4));

  /// Строки каналов, маленькие кнопки, плашки имён на плитках.
  static const double smPx = 8;
  static const BorderRadius sm = BorderRadius.all(Radius.circular(8));

  /// Поля ввода, сегментированные переключатели.
  static const double mdPx = 10;
  static const BorderRadius md = BorderRadius.all(Radius.circular(10));

  /// Кнопки, карточки и группы настроек.
  static const double lgPx = 12;
  static const BorderRadius lg = BorderRadius.all(Radius.circular(12));

  /// Плитки голосового канала, баннер сервера, карточка участника.
  static const double xlPx = 16;
  static const BorderRadius xl = BorderRadius.all(Radius.circular(16));

  /// Модальные окна; верх нижнего листа на телефоне (22px).
  static const double xxlPx = 18;
  static const BorderRadius xxl = BorderRadius.all(Radius.circular(18));

  /// Аватары, переключатели, чипы ролей, поле сообщения на телефоне.
  static const double fullPx = 9999;
  static const BorderRadius full = BorderRadius.all(Radius.circular(9999));
}

/// Размеры элементов управления.
abstract final class YlSize {
  /// Маленькие кнопки и иконки в строках.
  static const double controlSm = 32;

  /// Поля ввода и селекты в настройках.
  static const double controlMd = 42;

  /// Главные кнопки онбординга и приглашений.
  static const double controlLg = 48;

  /// Минимальная зона нажатия на телефоне.
  static const double touchMin = 44;

  /// Рельса серверов на ПК (70px на телефоне).
  static const double railWidth = 72;
}

/// Размеры компонентов из превью (временно, tokens.local.json).
abstract final class YlMetrics {
  /// Обводка иконок 24 px (design/README.md).
  static const double iconStroke = 1.8;

  /// Обводка мелких иконок 16 px.
  static const double iconStrokeSm = 2;

  /// Иконка в строке канала.
  static const double iconSm = 16;

  /// Обводка фокуса с клавиатуры (в макетах нет; доступность).
  static const double focusRing = 2;

  /// Заблокированная строка с переключателем (Toggle/README.md).
  static const double disabledOpacity = 0.6;

  /// Переключатель.
  static const double toggleWidth = 44;

  /// Переключатель.
  static const double toggleHeight = 26;

  /// Бегунок переключателя.
  static const double toggleThumb = 20;

  /// Отступ бегунка от края дорожки.
  static const double toggleInset = 3;

  /// Высота варианта сегментированного выбора.
  static const double segmentHeight = 34;

  /// Отступ и зазор внутри подложки сегментов.
  static const double segmentInset = 3;

  /// Чип роли и реакции.
  static const double chipHeight = 28;

  /// Горизонтальный отступ чипа.
  static const double chipPadX = 10;

  /// Зазор между точкой и текстом чипа.
  static const double chipGap = 6;

  /// Точка цвета роли.
  static const double chipDot = 8;

  /// Бейдж и счётчик.
  static const double badgePadX = 6;

  /// Бейдж.
  static const double badgePadY = 2;

  /// Высота и минимальная ширина счётчика.
  static const double counterSize = 20;

  /// Полоса состояния (по горизонтали — space-4).
  static const double bannerPadY = 10;

  /// Зазор в полосе состояния.
  static const double bannerGap = 10;

  /// Кнопка «Повторить сейчас» в полосе.
  static const double bannerActionHeight = 30;

  /// Ширина колонки каналов в превью ChannelRow.
  static const double channelColumnWidth = 248;

  /// Строка канала на ПК.
  static const double channelRowHeight = 34;

  /// Строка канала на телефоне.
  static const double channelRowHeightTouch = 40;

  /// Точка статуса на аватаре.
  static const double avatarDot = 10;

  /// Обводка точки статуса цветом фона.
  static const double avatarDotBorder = 3;

  /// Сдвиг точки статуса за край аватара.
  static const double avatarDotOffset = -2;

  /// Зазор и толщина кольца говорящего.
  static const double avatarRing = 3;
}
