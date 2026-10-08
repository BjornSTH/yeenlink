/// ВРЕМЕННО: размеры из макетов фазы 2, которых пока нет в
/// docs/design/tokens.json. Запрошены в дизайн-системе (отчёт фазы 2);
/// после новой выгрузки — заменить на YlSize и удалить файл.
abstract final class YlPending {
  /// Колонка участников на ПК (Main: aside «Участники сервера»).
  static const double membersColumnW = 240;

  /// Шапка колонок, чата и экранов на телефоне.
  static const double headerH = 56;

  /// Панель пользователя внизу колонки каналов.
  static const double userPanelH = 60;

  /// Модальное окно (AdminClaim).
  static const double modalW = 540;

  /// Кнопка «Закрыть» в модальном окне.
  static const double closeButton = 36;

  /// Колонка пустого состояния «Здесь пока тихо» на ПК.
  static const double emptyStateW = 760;

  /// Отступ внутри карточки пустого состояния.
  static const double cardPad = 18;

  /// Плитка иконки в карточке.
  static const double iconTile = 44;

  /// Иконки 18, 20 и 22 (закрыть; рельса; карточки и нижняя навигация).
  static const double iconMd = 18;
  static const double iconLg = 20;
  static const double iconXl = 22;

  /// Индикатор выбранного сервера в рельсе.
  static const double railIndicatorW = 4;
  static const double railIndicatorH = 28;

  /// Разделитель под логотипом в рельсе.
  static const double railDividerH = 2;

  /// Рельса и её элементы на телефоне (MobileApp).
  static const double railWidthPhone = 70;

  /// Шапка сервера с баннером на телефоне.
  static const double serverBannerH = 84;

  /// Нижняя навигация на телефоне.
  static const double bottomNavH = 66;

  /// Отметка «Готово» в окне ключа администратора и её галочка.
  static const double doneMark = 52;
  static const double doneMarkIcon = 26;
}
