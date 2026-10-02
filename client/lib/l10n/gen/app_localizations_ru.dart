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

  @override
  String get onbAsideTitle => 'Свои серверы.\nСвой профиль.';

  @override
  String get onbFeatureVpsTitle => 'Сервер на дешёвом VPS';

  @override
  String get onbFeatureVpsText => 'Ставится одной командой, работает даже на самом простом тарифе.';

  @override
  String get onbFeatureProfileTitle => 'Профиль всегда с вами';

  @override
  String get onbFeatureProfileText => 'Имя, аватар и стена переезжают с вами между серверами.';

  @override
  String get onbFeatureKeyTitle => 'Ключ вместо пароля';

  @override
  String get onbFeatureKeyText => 'Никто, кроме вас, не войдёт в ваш профиль — даже админ сервера.';

  @override
  String get onbAsideFooter => 'Открытый код · self-hosted';

  @override
  String onbStep(int step, int total) {
    return 'Шаг $step из $total';
  }

  @override
  String get onbBack => 'Назад';

  @override
  String get onbNext => 'Дальше';

  @override
  String get onbWelcomeTitle => 'Добро пожаловать в YeenLink';

  @override
  String get onbWelcomeText =>
      'Ваш профиль хранится у вас, а не на чужом сервере. Создайте его один раз и заходите с ним на любой сервер.';

  @override
  String get onbWelcomeCreate => 'Создать профиль';

  @override
  String get onbWelcomeRestore => 'У меня уже есть профиль';

  @override
  String get onbWelcomeNote => 'Без почты и номера телефона. Займёт около минуты.';

  @override
  String get onbProfileTitle => 'Как вас называть?';

  @override
  String get onbProfileText =>
      'Имя и аватар увидят на серверах, куда вы зайдёте. Поменять можно в любой момент.';

  @override
  String get onbAvatarPick => 'Выбрать аватар';

  @override
  String get onbAvatarChange => 'Сменить аватар';

  @override
  String get onbAvatarError => 'Не получилось открыть картинку. Подойдёт PNG, JPEG или WebP.';

  @override
  String get onbBannerColor => 'Цвет баннера';

  @override
  String onbBannerColorN(int n) {
    return 'Цвет баннера $n';
  }

  @override
  String get onbName => 'Имя';

  @override
  String get onbNameHint => 'Например, Пятнистый';

  @override
  String onbNameTooLong(int max) {
    return 'Имя длиннее $max символов.';
  }

  @override
  String get onbNameControl => 'В имени есть невидимые служебные символы — уберите их.';

  @override
  String get onbAbout => 'О себе (необязательно)';

  @override
  String get onbAboutHint => 'Пара слов о себе';

  @override
  String onbAboutTooLong(int max) {
    return 'Слишком длинно: до $max символов.';
  }

  @override
  String get onbNameEmpty => 'Введите имя';

  @override
  String get onbSeedTitle => 'Секретная фраза';

  @override
  String get onbSeedText =>
      'Эти 12 слов и есть ваш профиль. Только по ним можно вернуть доступ, если устройство потеряется. Мы их не храним и подсказать не сможем.';

  @override
  String get onbSeedWarning =>
      'Запишите на бумаге. Не отправляйте в чаты, не фотографируйте и никому не показывайте.';

  @override
  String get onbSeedCopy => 'Скопировать';

  @override
  String get onbSeedCopied => 'Скопировано. Через минуту буфер обмена очистится.';

  @override
  String get onbSeedSave => 'Сохранить в файл';

  @override
  String get onbSeedSaveWarning =>
      'Не сохраняйте файл в папки, которые синхронизируются с облаком (Google Диск, OneDrive, Яндекс Диск), и в общие папки.';

  @override
  String get onbSeedSaveChoose => 'Выбрать, куда сохранить';

  @override
  String get onbSeedSaved => 'Файл сохранён.';

  @override
  String get onbSeedSaveFailed => 'Не получилось сохранить файл. Запишите фразу на бумаге.';

  @override
  String get onbSeedConfirm => 'Я записал фразу в надёжном месте';

  @override
  String get onbSeedFileName => 'yeenlink-recovery.txt';

  @override
  String onbSeedFileText(String words) {
    return 'YeenLink — секретная фраза\n\n$words\n\nЭти 12 слов и есть ваш профиль. По ним можно войти в него с любого устройства.\nНе храните файл в папках, которые синхронизируются с облаком, и никому его не показывайте.\n';
  }

  @override
  String get onbPinTitle => 'Придумайте PIN-код';

  @override
  String get onbPinText =>
      '6 цифр. PIN нужен, чтобы показать секретную фразу и привязать или отвязать устройство. Без него ключ на этом устройстве не расшифровать.';

  @override
  String get onbPin => 'PIN-код';

  @override
  String get onbPinRepeat => 'Повторите PIN-код';

  @override
  String get onbPinMismatch => 'PIN-коды не совпадают.';

  @override
  String get onbPinSaving => 'Сохраняю ключ…';

  @override
  String onbPinSaveFailed(String reason) {
    return 'Не получилось сохранить ключ в хранилище системы: $reason';
  }

  @override
  String get onbJoinTitle => 'Подключитесь к серверу';

  @override
  String get onbJoinText =>
      'Вставьте приглашение, которое вам прислали, или найдите открытый сервер в каталоге.';

  @override
  String get onbJoinInvite => 'Приглашение';

  @override
  String get onbJoinInviteHint => 'yl://nightcamp.ru/… или IP-адрес';

  @override
  String get onbJoinConnect => 'Подключиться';

  @override
  String get onbJoinOr => 'или';

  @override
  String get onbJoinCatalog => 'Открыть каталог серверов';

  @override
  String get onbJoinSkip => 'Пропустить пока';

  @override
  String get onbJoinNotReady =>
      'Подключение к серверам появится в фазе 2. Пока нажмите «Пропустить пока».';

  @override
  String get onbCatalogNotReady => 'Каталог серверов появится в фазе 8.';

  @override
  String get onbRestoreTitle => 'Восстановить профиль';

  @override
  String get onbRestoreText =>
      'Войдите по секретной фразе или перенесите профиль с другого устройства.';

  @override
  String get onbRestoreTabPhrase => 'Секретная фраза';

  @override
  String get onbRestoreTabQr => 'QR с другого устройства';

  @override
  String get onbRestorePhrase => '12 слов через пробел';

  @override
  String get onbRestorePhraseHint => 'maple orbit canyon …';

  @override
  String get onbRestoreAction => 'Восстановить';

  @override
  String get onbRestoreChecking => 'Проверяю фразу…';

  @override
  String onbRestoreWordCount(int count) {
    return 'Нужно 12 слов — сейчас $count.';
  }

  @override
  String onbRestoreUnknownWord(int n, String word) {
    return 'Слово $n «$word» не из списка. Проверьте написание.';
  }

  @override
  String get onbRestoreChecksum =>
      'Все слова из списка, но фраза не сходится. Проверьте порядок слов и опечатки.';

  @override
  String get onbRestoreQrStub =>
      'Перенос с другого устройства появится в фазе 7. Пока войдите по секретной фразе.';

  @override
  String get onbDoneTitle => 'Профиль готов';

  @override
  String get onbDoneText =>
      'Ключ сохранён на этом устройстве. Секретная фраза — ваша страховка, держите её в надёжном месте.';

  @override
  String get onbDoneRestoredText =>
      'Профиль восстановлен на этом устройстве. Имя и аватар подтянутся с сервера, когда вы к нему подключитесь.';

  @override
  String get onbDoneOpen => 'Открыть YeenLink';

  @override
  String deviceNameComputer(String os) {
    return 'Компьютер · $os';
  }

  @override
  String deviceNamePhone(String model) {
    return 'Телефон · $model';
  }

  @override
  String get deviceNamePhoneUnknown => 'Телефон';

  @override
  String get homeProfileRestored => 'Профиль восстановлен';

  @override
  String get homeFingerprint => 'Отпечаток ключа';

  @override
  String get homeDevice => 'Это устройство';

  @override
  String get homeNoServers => 'Серверов пока нет: подключение появится в фазе 2.';

  @override
  String homeLoadFailed(String reason) {
    return 'Не получилось прочитать профиль на этом устройстве: $reason';
  }

  @override
  String get onbRestoreEnterPhrase => 'Введите 12 слов';

  @override
  String get onbPinEnterTwice => 'Введите PIN дважды';

  @override
  String get onbTextBidi =>
      'Здесь есть невидимые символы направления текста — ими подделывают имена. Уберите их.';
}
