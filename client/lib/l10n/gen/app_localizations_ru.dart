// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class L10nRu extends L10n {
  L10nRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'YeenLink';

  @override
  String get appSkeleton =>
      'Каркас клиента. Компоненты — в витрине: flutter run -t lib/main_showcase.dart';

  @override
  String get redactedHidden => 'скрыто';

  @override
  String get redactedServerName => 'Сервер скрыт';

  @override
  String segmentUnavailable(String label) {
    return '$label · нет';
  }

  @override
  String reactionCount(String reaction, int count) {
    return '$reaction · $count';
  }

  @override
  String get badgeLive => 'ЭФИР';

  @override
  String get badgeBot => 'БОТ';

  @override
  String get badgeCountOverflow => '99+';

  @override
  String get statusOnline => 'В сети';

  @override
  String get statusIdle => 'Отошёл';

  @override
  String get statusDnd => 'Не беспокоить';

  @override
  String get statusOffline => 'Не в сети';

  @override
  String get bannerRetry => 'Повторить сейчас';

  @override
  String get scTitle => 'Витрина компонентов';

  @override
  String get scThemeDark => 'Тёмная матовая';

  @override
  String get scThemeLight => 'Светлая матовая';

  @override
  String get scSectionButton => 'Кнопка';

  @override
  String get scSectionToggle => 'Переключатель';

  @override
  String get scSectionSegmented => 'Сегменты';

  @override
  String get scSectionInput => 'Поле ввода';

  @override
  String get scSectionAvatar => 'Аватар';

  @override
  String get scSectionChip => 'Чип';

  @override
  String get scSectionBadge => 'Бейдж';

  @override
  String get scSectionBanner => 'Полоса состояния';

  @override
  String get scSectionChannelRow => 'Строка канала';

  @override
  String get scButtonJoin => 'Присоединиться';

  @override
  String get scButtonHaveProfile => 'У меня уже есть профиль';

  @override
  String get scButtonBack => 'Назад';

  @override
  String get scButtonLeave => 'Покинуть';

  @override
  String get scButtonDisabled => 'Выберите, что показать';

  @override
  String get scButtonManage => 'Управлять';

  @override
  String get scToggleNoise => 'Шумоподавление';

  @override
  String get scToggleNoiseHint => 'Убирает фон: клавиатуру, вентилятор, улицу.';

  @override
  String get scTogglePtt => 'Режим рации';

  @override
  String get scTogglePttHint => 'Микрофон работает, пока держите клавишу.';

  @override
  String get scToggleLocked => 'Пускать без одобрения';

  @override
  String get scToggleLockedReason => 'Это меняет только Владелец сервера.';

  @override
  String get scToggleStreamer => 'Режим стримера';

  @override
  String get scToggleStreamerHint => 'Прячет адреса и названия серверов на этой витрине.';

  @override
  String get scSegStreamNote => 'Сервер разрешает стрим до 720p.';

  @override
  String get scSegAll => 'Все';

  @override
  String get scSegPending => 'Ожидают';

  @override
  String get scSegBans => 'Баны';

  @override
  String get scInputName => 'Отображаемое имя';

  @override
  String get scInputNameValue => 'Пятнистый';

  @override
  String get scInputInvite => 'Приглашение';

  @override
  String get scInputInviteHint => 'yl://… или IP-адрес';

  @override
  String get scInputAbout => 'О себе (необязательно)';

  @override
  String get scNameKrivozub => 'Кривозуб';

  @override
  String get scNameSavanna => 'Саванна';

  @override
  String get scNameKhokhotun => 'Хохотун';

  @override
  String get scNameSpotted => 'Пятнистый';

  @override
  String get scServerName => 'Ночной привал';

  @override
  String get scRoleMaster => 'Мастер';

  @override
  String get scRolePlayer => 'Игрок';

  @override
  String get scRoleGuest => 'Гость';

  @override
  String get scRoleBot => 'Бот';

  @override
  String get scReactionDice => 'к20';

  @override
  String scBannerReconnecting(String server, int n, int total) {
    return 'Связь с $server потеряна. Пробую запасной адрес $n из $total…';
  }

  @override
  String get scBannerFailover => 'Подключено через запасной адрес. Основной проверяю раз в минуту.';

  @override
  String get scBannerOffline =>
      'Сервер недоступен по всем трём адресам. Сообщения уйдут, когда связь вернётся.';

  @override
  String get scChannelGeneral => 'общий';

  @override
  String get scChannelNews => 'анонсы';

  @override
  String get scChannelScreens => 'скриншоты';

  @override
  String get scChannelTavern => 'Таверна';
}
