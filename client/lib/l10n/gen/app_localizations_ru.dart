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
  String get homeFingerprint => 'Отпечаток ключа';

  @override
  String get homeDevice => 'Это устройство';

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

  @override
  String get onbRestoredProfileText =>
      'Если вы уже заходили на серверы, имя и аватар подтянутся оттуда при подключении. Можно указать сейчас.';

  @override
  String get onbRestoreSaving => 'Восстанавливаю…';

  @override
  String get onbSaving => 'Сохраняю…';

  @override
  String onbProfileSaveFailed(String reason) {
    return 'Не получилось сохранить профиль: $reason';
  }

  @override
  String get homeNoName => 'Имя не указано';

  @override
  String get commonOk => 'Понятно';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonBack => 'Назад';

  @override
  String get emptyTitle => 'Здесь пока тихо';

  @override
  String get emptyBodyPc =>
      'У вас ещё нет ни одного сервера. Выберите, с чего начать — профиль уже готов и поедет с вами куда угодно.';

  @override
  String get emptyBodyPhone => 'Серверов пока нет. Начните с одного из вариантов.';

  @override
  String get emptyInviteTitle => 'Вставить приглашение';

  @override
  String get emptyInviteBody => 'Если вам прислали ссылку или QR-код.';

  @override
  String get emptyCatalogTitle => 'Найти в каталоге';

  @override
  String get emptyCatalogBody => 'Открытые сообщества по интересам.';

  @override
  String get emptyOwnTitle => 'Поднять свой сервер';

  @override
  String get emptyOwnBodyPc => 'Один бинарник, хватит VPS за 200 ₽. Инструкция — в документации.';

  @override
  String get emptyOwnBodyPhone => 'Один бинарник, хватит VPS за 200 ₽.';

  @override
  String get catalogSoonTitle => 'Каталог серверов';

  @override
  String get catalogSoonBody =>
      'Каталог пока не работает — он появится в следующих версиях. Подключиться можно по адресу сервера.';

  @override
  String get ownTitle => 'Свой сервер';

  @override
  String get ownBody =>
      'Сервер YeenLink — один файл ylsrv. Скопируйте его на VPS с Linux и выполните:';

  @override
  String get ownAfter =>
      'ylsrv init покажет ключ сервера и ключ администратора. Добавьте сервер по адресу, сверьте ключ и станьте владельцем.';

  @override
  String get ownAdd => 'Добавить сервер';

  @override
  String get addTitle => 'Добавить сервер';

  @override
  String get addBody =>
      'Введите адрес сервера: домен или IP, если нужно — с портом. Вход по приглашению появится позже.';

  @override
  String get addLabel => 'Адрес сервера';

  @override
  String get addPlaceholder => 'chat.example.org или 203.0.113.7:8443';

  @override
  String get addCheck => 'Продолжить';

  @override
  String get addChecking => 'Проверяю адрес…';

  @override
  String addConfirmBody(String server) {
    return 'Сервер «$server». Сверьте его ключ с тем, что показал ylsrv init на сервере:';
  }

  @override
  String get addKeyLabel => 'Ключ сервера';

  @override
  String get addConfirmHint =>
      'Совпадает — подключайтесь. Не совпадает — не подключайтесь: это может быть чужой сервер, который выдаёт себя за ваш.';

  @override
  String get addConnect => 'Подключиться';

  @override
  String get addConnecting => 'Подключаюсь…';

  @override
  String get addErrEmpty => 'Введите адрес.';

  @override
  String get addErrAddress => 'Не похоже на адрес сервера. Пример: chat.example.org:8443';

  @override
  String get addErrScheme => 'Адрес пишется без схемы или с https://.';

  @override
  String get addErrFingerprint =>
      'После # нужен отпечаток из четырёх групп, например A0D2·5F11·0C3E·99AB.';

  @override
  String get linkUnreachable => 'Сервер не отвечает по этому адресу. Проверьте адрес и порт.';

  @override
  String get linkNotYeenLink => 'По этому адресу не сервер YeenLink.';

  @override
  String get linkWrongServer =>
      'Это не тот сервер: его ключ не совпадает с ожидаемым. Не подключайтесь.';

  @override
  String get linkCertNotSigned =>
      'Сертификат сервера не подписан его ключом — соединение могли подменить. Не подключайтесь через эту сеть.';

  @override
  String get linkDeviceRevoked => 'Это устройство отвязано от вашего профиля.';

  @override
  String get linkProto =>
      'Сервер говорит на другой версии протокола. Обновите приложение или сервер.';

  @override
  String get linkRejected => 'Сервер не пустил это устройство.';

  @override
  String get linkClosed => 'Связь с сервером оборвалась.';

  @override
  String get linkReplaced => 'Вы подключились к этому серверу в другом окне.';

  @override
  String get claimTitle => 'Стать владельцем сервера';

  @override
  String get claimTitlePhone => 'Ключ администратора';

  @override
  String claimBody(String server) {
    return 'У сервера «$server» пока нет владельца. Если сервер установили вы, введите ключ администратора: сервер показал его один раз при первом запуске — в консоли и в файле на сервере.';
  }

  @override
  String get claimLostKey => 'Потеряли ключ? Выпустите новый на сервере:';

  @override
  String get claimConsoleProof => 'Доступ к консоли сервера и есть доказательство, что он ваш.';

  @override
  String get claimLabel => 'Ключ администратора';

  @override
  String claimNote(String fingerprint) {
    return 'Роль Владельца привяжется к вашему ключу $fingerprint. Ключ администратора одноразовый и сгорит сразу после использования.';
  }

  @override
  String get claimButton => 'Стать владельцем';

  @override
  String get claimChecking => 'Проверяю ключ…';

  @override
  String claimDone(String server) {
    return 'Готово. Теперь вы Владелец сервера «$server». Ключ администратора сгорел — для следующей передачи выпустите новый.';
  }

  @override
  String get claimDoneButton => 'Перейти к серверу';

  @override
  String get claimErrFormat =>
      'Ключ начинается с ylat_, в нём 48 символов. Скопируйте его целиком.';

  @override
  String get claimErrBadToken =>
      'Ключ не подошёл. Возможно, им уже воспользовались — выпустите новый: ylsrv admin-token.';

  @override
  String get claimErrRate => 'Слишком много попыток. Повторите через минуту.';

  @override
  String get claimErrOffline => 'Нет связи с сервером. Повторите, когда она вернётся.';

  @override
  String get railHome => 'YeenLink';

  @override
  String get railAdd => 'Добавить сервер';

  @override
  String get railCatalog => 'Каталог серверов';

  @override
  String get srvNoOwnerTitle => 'У сервера пока нет владельца';

  @override
  String get srvNoOwnerBody =>
      'Если сервер установили вы, станьте владельцем по ключу администратора.';

  @override
  String get srvNoOwnerAction => 'Ввести ключ администратора';

  @override
  String get srvNoChannelsTitle => 'Каналов пока нет';

  @override
  String get srvNoChannelsBody => 'Когда на сервере появятся каналы, они будут здесь.';

  @override
  String get srvConnectingTitle => 'Подключаюсь…';

  @override
  String get srvMembers => 'Участники';

  @override
  String srvOnline(int count) {
    return '$count в сети';
  }

  @override
  String srvGroupOwner(int count) {
    return 'ВЛАДЕЛЕЦ — $count';
  }

  @override
  String srvGroupOnline(int count) {
    return 'В СЕТИ — $count';
  }

  @override
  String get srvItsYou => 'Это вы';

  @override
  String get connRetrying => 'Связь с сервером потеряна. Переподключаюсь…';

  @override
  String get connRetryNow => 'Повторить сейчас';

  @override
  String get connUnbound =>
      'Сервер не подтвердил свой сертификат — он за прокси без tls.proxy_cert. Подмену соединения исключить нельзя.';

  @override
  String get navServers => 'Серверы';

  @override
  String get navFeed => 'Лента';

  @override
  String get navDms => 'Личные';

  @override
  String get navProfile => 'Профиль';

  @override
  String get feedEmptyTitle => 'Ленты пока нет';

  @override
  String get feedEmptyBody => 'Здесь будут посты с ваших серверов.';

  @override
  String get dmsEmptyTitle => 'Личных сообщений пока нет';

  @override
  String get dmsEmptyBody => 'Здесь будут переписки один на один.';

  @override
  String get pinTitle => 'Подтвердите PIN-код';

  @override
  String get pinBody =>
      'Этого устройства ещё нет в списке ваших устройств. Введите PIN-код — приложение подпишет новый список, и серверы будут знать, что устройство ваше. Это нужно один раз.';

  @override
  String get pinLabel => 'PIN-код';

  @override
  String get pinConfirm => 'Подтвердить';

  @override
  String get pinLater => 'Не сейчас';

  @override
  String get pinWrong => 'PIN-код не подошёл.';

  @override
  String pinWait(int seconds) {
    return 'Слишком много попыток. Подождите $seconds с.';
  }
}
