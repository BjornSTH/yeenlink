import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'YeenLink'**
  String get appTitle;

  /// No description provided for @appSkeleton.
  ///
  /// In ru, this message translates to:
  /// **'Каркас клиента. Компоненты — в витрине: flutter run -t lib/main_showcase.dart'**
  String get appSkeleton;

  /// Заглушка режима стримера для адресов, IP, портов, отпечатков, handle и приглашений. Длина фиксированная.
  ///
  /// In ru, this message translates to:
  /// **'скрыто'**
  String get redactedHidden;

  /// Заглушка режима стримера вместо названия сервера.
  ///
  /// In ru, this message translates to:
  /// **'Сервер скрыт'**
  String get redactedServerName;

  /// Недоступный вариант в сегментах.
  ///
  /// In ru, this message translates to:
  /// **'{label} · нет'**
  String segmentUnavailable(String label);

  /// No description provided for @reactionCount.
  ///
  /// In ru, this message translates to:
  /// **'{reaction} · {count}'**
  String reactionCount(String reaction, int count);

  /// No description provided for @badgeLive.
  ///
  /// In ru, this message translates to:
  /// **'ЭФИР'**
  String get badgeLive;

  /// No description provided for @badgeBot.
  ///
  /// In ru, this message translates to:
  /// **'БОТ'**
  String get badgeBot;

  /// No description provided for @badgeCountOverflow.
  ///
  /// In ru, this message translates to:
  /// **'99+'**
  String get badgeCountOverflow;

  /// No description provided for @statusOnline.
  ///
  /// In ru, this message translates to:
  /// **'В сети'**
  String get statusOnline;

  /// No description provided for @statusIdle.
  ///
  /// In ru, this message translates to:
  /// **'Отошёл'**
  String get statusIdle;

  /// No description provided for @statusDnd.
  ///
  /// In ru, this message translates to:
  /// **'Не беспокоить'**
  String get statusDnd;

  /// No description provided for @statusOffline.
  ///
  /// In ru, this message translates to:
  /// **'Не в сети'**
  String get statusOffline;

  /// No description provided for @bannerRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить сейчас'**
  String get bannerRetry;

  /// No description provided for @scTitle.
  ///
  /// In ru, this message translates to:
  /// **'Витрина компонентов'**
  String get scTitle;

  /// No description provided for @scThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная матовая'**
  String get scThemeDark;

  /// No description provided for @scThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая матовая'**
  String get scThemeLight;

  /// No description provided for @scSectionButton.
  ///
  /// In ru, this message translates to:
  /// **'Кнопка'**
  String get scSectionButton;

  /// No description provided for @scSectionToggle.
  ///
  /// In ru, this message translates to:
  /// **'Переключатель'**
  String get scSectionToggle;

  /// No description provided for @scSectionSegmented.
  ///
  /// In ru, this message translates to:
  /// **'Сегменты'**
  String get scSectionSegmented;

  /// No description provided for @scSectionInput.
  ///
  /// In ru, this message translates to:
  /// **'Поле ввода'**
  String get scSectionInput;

  /// No description provided for @scSectionAvatar.
  ///
  /// In ru, this message translates to:
  /// **'Аватар'**
  String get scSectionAvatar;

  /// No description provided for @scSectionChip.
  ///
  /// In ru, this message translates to:
  /// **'Чип'**
  String get scSectionChip;

  /// No description provided for @scSectionBadge.
  ///
  /// In ru, this message translates to:
  /// **'Бейдж'**
  String get scSectionBadge;

  /// No description provided for @scSectionBanner.
  ///
  /// In ru, this message translates to:
  /// **'Полоса состояния'**
  String get scSectionBanner;

  /// No description provided for @scSectionChannelRow.
  ///
  /// In ru, this message translates to:
  /// **'Строка канала'**
  String get scSectionChannelRow;

  /// No description provided for @scButtonJoin.
  ///
  /// In ru, this message translates to:
  /// **'Присоединиться'**
  String get scButtonJoin;

  /// No description provided for @scButtonHaveProfile.
  ///
  /// In ru, this message translates to:
  /// **'У меня уже есть профиль'**
  String get scButtonHaveProfile;

  /// No description provided for @scButtonBack.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get scButtonBack;

  /// No description provided for @scButtonLeave.
  ///
  /// In ru, this message translates to:
  /// **'Покинуть'**
  String get scButtonLeave;

  /// No description provided for @scButtonDisabled.
  ///
  /// In ru, this message translates to:
  /// **'Выберите, что показать'**
  String get scButtonDisabled;

  /// No description provided for @scButtonManage.
  ///
  /// In ru, this message translates to:
  /// **'Управлять'**
  String get scButtonManage;

  /// No description provided for @scToggleNoise.
  ///
  /// In ru, this message translates to:
  /// **'Шумоподавление'**
  String get scToggleNoise;

  /// No description provided for @scToggleNoiseHint.
  ///
  /// In ru, this message translates to:
  /// **'Убирает фон: клавиатуру, вентилятор, улицу.'**
  String get scToggleNoiseHint;

  /// No description provided for @scTogglePtt.
  ///
  /// In ru, this message translates to:
  /// **'Режим рации'**
  String get scTogglePtt;

  /// No description provided for @scTogglePttHint.
  ///
  /// In ru, this message translates to:
  /// **'Микрофон работает, пока держите клавишу.'**
  String get scTogglePttHint;

  /// No description provided for @scToggleLocked.
  ///
  /// In ru, this message translates to:
  /// **'Пускать без одобрения'**
  String get scToggleLocked;

  /// No description provided for @scToggleLockedReason.
  ///
  /// In ru, this message translates to:
  /// **'Это меняет только Владелец сервера.'**
  String get scToggleLockedReason;

  /// No description provided for @scToggleStreamer.
  ///
  /// In ru, this message translates to:
  /// **'Режим стримера'**
  String get scToggleStreamer;

  /// No description provided for @scToggleStreamerHint.
  ///
  /// In ru, this message translates to:
  /// **'Прячет адреса и названия серверов на этой витрине.'**
  String get scToggleStreamerHint;

  /// No description provided for @scSegStreamNote.
  ///
  /// In ru, this message translates to:
  /// **'Сервер разрешает стрим до 720p.'**
  String get scSegStreamNote;

  /// No description provided for @scSegAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get scSegAll;

  /// No description provided for @scSegPending.
  ///
  /// In ru, this message translates to:
  /// **'Ожидают'**
  String get scSegPending;

  /// No description provided for @scSegBans.
  ///
  /// In ru, this message translates to:
  /// **'Баны'**
  String get scSegBans;

  /// No description provided for @scInputName.
  ///
  /// In ru, this message translates to:
  /// **'Отображаемое имя'**
  String get scInputName;

  /// No description provided for @scInputNameValue.
  ///
  /// In ru, this message translates to:
  /// **'Пятнистый'**
  String get scInputNameValue;

  /// No description provided for @scInputInvite.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение'**
  String get scInputInvite;

  /// No description provided for @scInputInviteHint.
  ///
  /// In ru, this message translates to:
  /// **'yl://… или IP-адрес'**
  String get scInputInviteHint;

  /// No description provided for @scInputAbout.
  ///
  /// In ru, this message translates to:
  /// **'О себе (необязательно)'**
  String get scInputAbout;

  /// No description provided for @scNameKrivozub.
  ///
  /// In ru, this message translates to:
  /// **'Кривозуб'**
  String get scNameKrivozub;

  /// No description provided for @scNameSavanna.
  ///
  /// In ru, this message translates to:
  /// **'Саванна'**
  String get scNameSavanna;

  /// No description provided for @scNameKhokhotun.
  ///
  /// In ru, this message translates to:
  /// **'Хохотун'**
  String get scNameKhokhotun;

  /// No description provided for @scNameSpotted.
  ///
  /// In ru, this message translates to:
  /// **'Пятнистый'**
  String get scNameSpotted;

  /// No description provided for @scServerName.
  ///
  /// In ru, this message translates to:
  /// **'Ночной привал'**
  String get scServerName;

  /// No description provided for @scRoleMaster.
  ///
  /// In ru, this message translates to:
  /// **'Мастер'**
  String get scRoleMaster;

  /// No description provided for @scRolePlayer.
  ///
  /// In ru, this message translates to:
  /// **'Игрок'**
  String get scRolePlayer;

  /// No description provided for @scRoleGuest.
  ///
  /// In ru, this message translates to:
  /// **'Гость'**
  String get scRoleGuest;

  /// No description provided for @scRoleBot.
  ///
  /// In ru, this message translates to:
  /// **'Бот'**
  String get scRoleBot;

  /// No description provided for @scReactionDice.
  ///
  /// In ru, this message translates to:
  /// **'к20'**
  String get scReactionDice;

  /// No description provided for @scBannerReconnecting.
  ///
  /// In ru, this message translates to:
  /// **'Связь с {server} потеряна. Пробую запасной адрес {n} из {total}…'**
  String scBannerReconnecting(String server, int n, int total);

  /// No description provided for @scBannerFailover.
  ///
  /// In ru, this message translates to:
  /// **'Подключено через запасной адрес. Основной проверяю раз в минуту.'**
  String get scBannerFailover;

  /// No description provided for @scBannerOffline.
  ///
  /// In ru, this message translates to:
  /// **'Сервер недоступен по всем трём адресам. Сообщения уйдут, когда связь вернётся.'**
  String get scBannerOffline;

  /// No description provided for @scChannelGeneral.
  ///
  /// In ru, this message translates to:
  /// **'общий'**
  String get scChannelGeneral;

  /// No description provided for @scChannelNews.
  ///
  /// In ru, this message translates to:
  /// **'анонсы'**
  String get scChannelNews;

  /// No description provided for @scChannelScreens.
  ///
  /// In ru, this message translates to:
  /// **'скриншоты'**
  String get scChannelScreens;

  /// No description provided for @scChannelTavern.
  ///
  /// In ru, this message translates to:
  /// **'Таверна'**
  String get scChannelTavern;

  /// No description provided for @onbAsideTitle.
  ///
  /// In ru, this message translates to:
  /// **'Свои серверы.\nСвой профиль.'**
  String get onbAsideTitle;

  /// No description provided for @onbFeatureVpsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сервер на дешёвом VPS'**
  String get onbFeatureVpsTitle;

  /// No description provided for @onbFeatureVpsText.
  ///
  /// In ru, this message translates to:
  /// **'Ставится одной командой, работает даже на самом простом тарифе.'**
  String get onbFeatureVpsText;

  /// No description provided for @onbFeatureProfileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль всегда с вами'**
  String get onbFeatureProfileTitle;

  /// No description provided for @onbFeatureProfileText.
  ///
  /// In ru, this message translates to:
  /// **'Имя, аватар и стена переезжают с вами между серверами.'**
  String get onbFeatureProfileText;

  /// No description provided for @onbFeatureKeyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ключ вместо пароля'**
  String get onbFeatureKeyTitle;

  /// No description provided for @onbFeatureKeyText.
  ///
  /// In ru, this message translates to:
  /// **'Никто, кроме вас, не войдёт в ваш профиль — даже админ сервера.'**
  String get onbFeatureKeyText;

  /// No description provided for @onbAsideFooter.
  ///
  /// In ru, this message translates to:
  /// **'Открытый код · self-hosted'**
  String get onbAsideFooter;

  /// No description provided for @onbStep.
  ///
  /// In ru, this message translates to:
  /// **'Шаг {step} из {total}'**
  String onbStep(int step, int total);

  /// No description provided for @onbBack.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get onbBack;

  /// No description provided for @onbNext.
  ///
  /// In ru, this message translates to:
  /// **'Дальше'**
  String get onbNext;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Добро пожаловать в YeenLink'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeText.
  ///
  /// In ru, this message translates to:
  /// **'Ваш профиль хранится у вас, а не на чужом сервере. Создайте его один раз и заходите с ним на любой сервер.'**
  String get onbWelcomeText;

  /// No description provided for @onbWelcomeCreate.
  ///
  /// In ru, this message translates to:
  /// **'Создать профиль'**
  String get onbWelcomeCreate;

  /// No description provided for @onbWelcomeRestore.
  ///
  /// In ru, this message translates to:
  /// **'У меня уже есть профиль'**
  String get onbWelcomeRestore;

  /// No description provided for @onbWelcomeNote.
  ///
  /// In ru, this message translates to:
  /// **'Без почты и номера телефона. Займёт около минуты.'**
  String get onbWelcomeNote;

  /// No description provided for @onbProfileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Как вас называть?'**
  String get onbProfileTitle;

  /// No description provided for @onbProfileText.
  ///
  /// In ru, this message translates to:
  /// **'Имя и аватар увидят на серверах, куда вы зайдёте. Поменять можно в любой момент.'**
  String get onbProfileText;

  /// No description provided for @onbAvatarPick.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать аватар'**
  String get onbAvatarPick;

  /// No description provided for @onbAvatarChange.
  ///
  /// In ru, this message translates to:
  /// **'Сменить аватар'**
  String get onbAvatarChange;

  /// No description provided for @onbAvatarError.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось открыть картинку. Подойдёт PNG, JPEG или WebP.'**
  String get onbAvatarError;

  /// No description provided for @onbBannerColor.
  ///
  /// In ru, this message translates to:
  /// **'Цвет баннера'**
  String get onbBannerColor;

  /// No description provided for @onbBannerColorN.
  ///
  /// In ru, this message translates to:
  /// **'Цвет баннера {n}'**
  String onbBannerColorN(int n);

  /// No description provided for @onbName.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get onbName;

  /// No description provided for @onbNameHint.
  ///
  /// In ru, this message translates to:
  /// **'Например, Пятнистый'**
  String get onbNameHint;

  /// No description provided for @onbNameTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Имя длиннее {max} символов.'**
  String onbNameTooLong(int max);

  /// No description provided for @onbNameControl.
  ///
  /// In ru, this message translates to:
  /// **'В имени есть невидимые служебные символы — уберите их.'**
  String get onbNameControl;

  /// No description provided for @onbAbout.
  ///
  /// In ru, this message translates to:
  /// **'О себе (необязательно)'**
  String get onbAbout;

  /// No description provided for @onbAboutHint.
  ///
  /// In ru, this message translates to:
  /// **'Пара слов о себе'**
  String get onbAboutHint;

  /// No description provided for @onbAboutTooLong.
  ///
  /// In ru, this message translates to:
  /// **'Слишком длинно: до {max} символов.'**
  String onbAboutTooLong(int max);

  /// No description provided for @onbNameEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Введите имя'**
  String get onbNameEmpty;

  /// No description provided for @onbSeedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Секретная фраза'**
  String get onbSeedTitle;

  /// No description provided for @onbSeedText.
  ///
  /// In ru, this message translates to:
  /// **'Эти 12 слов и есть ваш профиль. Только по ним можно вернуть доступ, если устройство потеряется. Мы их не храним и подсказать не сможем.'**
  String get onbSeedText;

  /// No description provided for @onbSeedWarning.
  ///
  /// In ru, this message translates to:
  /// **'Запишите на бумаге. Не отправляйте в чаты, не фотографируйте и никому не показывайте.'**
  String get onbSeedWarning;

  /// No description provided for @onbSeedCopy.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать'**
  String get onbSeedCopy;

  /// No description provided for @onbSeedCopied.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано. Через минуту буфер обмена очистится.'**
  String get onbSeedCopied;

  /// No description provided for @onbSeedSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить в файл'**
  String get onbSeedSave;

  /// No description provided for @onbSeedSaveWarning.
  ///
  /// In ru, this message translates to:
  /// **'Не сохраняйте файл в папки, которые синхронизируются с облаком (Google Диск, OneDrive, Яндекс Диск), и в общие папки.'**
  String get onbSeedSaveWarning;

  /// No description provided for @onbSeedSaveChoose.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать, куда сохранить'**
  String get onbSeedSaveChoose;

  /// No description provided for @onbSeedSaved.
  ///
  /// In ru, this message translates to:
  /// **'Файл сохранён.'**
  String get onbSeedSaved;

  /// No description provided for @onbSeedSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось сохранить файл. Запишите фразу на бумаге.'**
  String get onbSeedSaveFailed;

  /// No description provided for @onbSeedConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Я записал фразу в надёжном месте'**
  String get onbSeedConfirm;

  /// No description provided for @onbSeedFileName.
  ///
  /// In ru, this message translates to:
  /// **'yeenlink-recovery.txt'**
  String get onbSeedFileName;

  /// No description provided for @onbSeedFileText.
  ///
  /// In ru, this message translates to:
  /// **'YeenLink — секретная фраза\n\n{words}\n\nЭти 12 слов и есть ваш профиль. По ним можно войти в него с любого устройства.\nНе храните файл в папках, которые синхронизируются с облаком, и никому его не показывайте.\n'**
  String onbSeedFileText(String words);

  /// No description provided for @onbPinTitle.
  ///
  /// In ru, this message translates to:
  /// **'Придумайте PIN-код'**
  String get onbPinTitle;

  /// No description provided for @onbPinText.
  ///
  /// In ru, this message translates to:
  /// **'6 цифр. PIN нужен, чтобы показать секретную фразу и привязать или отвязать устройство. Без него ключ на этом устройстве не расшифровать.'**
  String get onbPinText;

  /// No description provided for @onbPin.
  ///
  /// In ru, this message translates to:
  /// **'PIN-код'**
  String get onbPin;

  /// No description provided for @onbPinRepeat.
  ///
  /// In ru, this message translates to:
  /// **'Повторите PIN-код'**
  String get onbPinRepeat;

  /// No description provided for @onbPinMismatch.
  ///
  /// In ru, this message translates to:
  /// **'PIN-коды не совпадают.'**
  String get onbPinMismatch;

  /// No description provided for @onbPinSaving.
  ///
  /// In ru, this message translates to:
  /// **'Сохраняю ключ…'**
  String get onbPinSaving;

  /// No description provided for @onbPinSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось сохранить ключ в хранилище системы: {reason}'**
  String onbPinSaveFailed(String reason);

  /// No description provided for @onbJoinTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подключитесь к серверу'**
  String get onbJoinTitle;

  /// No description provided for @onbJoinText.
  ///
  /// In ru, this message translates to:
  /// **'Вставьте приглашение, которое вам прислали, или найдите открытый сервер в каталоге.'**
  String get onbJoinText;

  /// No description provided for @onbJoinInvite.
  ///
  /// In ru, this message translates to:
  /// **'Приглашение'**
  String get onbJoinInvite;

  /// No description provided for @onbJoinInviteHint.
  ///
  /// In ru, this message translates to:
  /// **'yl://nightcamp.ru/… или IP-адрес'**
  String get onbJoinInviteHint;

  /// No description provided for @onbJoinConnect.
  ///
  /// In ru, this message translates to:
  /// **'Подключиться'**
  String get onbJoinConnect;

  /// No description provided for @onbJoinOr.
  ///
  /// In ru, this message translates to:
  /// **'или'**
  String get onbJoinOr;

  /// No description provided for @onbJoinCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Открыть каталог серверов'**
  String get onbJoinCatalog;

  /// No description provided for @onbJoinSkip.
  ///
  /// In ru, this message translates to:
  /// **'Пропустить пока'**
  String get onbJoinSkip;

  /// No description provided for @onbJoinNotReady.
  ///
  /// In ru, this message translates to:
  /// **'Подключение к серверам появится в фазе 2. Пока нажмите «Пропустить пока».'**
  String get onbJoinNotReady;

  /// No description provided for @onbCatalogNotReady.
  ///
  /// In ru, this message translates to:
  /// **'Каталог серверов появится в фазе 8.'**
  String get onbCatalogNotReady;

  /// No description provided for @onbRestoreTitle.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить профиль'**
  String get onbRestoreTitle;

  /// No description provided for @onbRestoreText.
  ///
  /// In ru, this message translates to:
  /// **'Войдите по секретной фразе или перенесите профиль с другого устройства.'**
  String get onbRestoreText;

  /// No description provided for @onbRestoreTabPhrase.
  ///
  /// In ru, this message translates to:
  /// **'Секретная фраза'**
  String get onbRestoreTabPhrase;

  /// No description provided for @onbRestoreTabQr.
  ///
  /// In ru, this message translates to:
  /// **'QR с другого устройства'**
  String get onbRestoreTabQr;

  /// No description provided for @onbRestorePhrase.
  ///
  /// In ru, this message translates to:
  /// **'12 слов через пробел'**
  String get onbRestorePhrase;

  /// No description provided for @onbRestorePhraseHint.
  ///
  /// In ru, this message translates to:
  /// **'maple orbit canyon …'**
  String get onbRestorePhraseHint;

  /// No description provided for @onbRestoreAction.
  ///
  /// In ru, this message translates to:
  /// **'Восстановить'**
  String get onbRestoreAction;

  /// No description provided for @onbRestoreChecking.
  ///
  /// In ru, this message translates to:
  /// **'Проверяю фразу…'**
  String get onbRestoreChecking;

  /// No description provided for @onbRestoreWordCount.
  ///
  /// In ru, this message translates to:
  /// **'Нужно 12 слов — сейчас {count}.'**
  String onbRestoreWordCount(int count);

  /// No description provided for @onbRestoreUnknownWord.
  ///
  /// In ru, this message translates to:
  /// **'Слово {n} «{word}» не из списка. Проверьте написание.'**
  String onbRestoreUnknownWord(int n, String word);

  /// No description provided for @onbRestoreChecksum.
  ///
  /// In ru, this message translates to:
  /// **'Все слова из списка, но фраза не сходится. Проверьте порядок слов и опечатки.'**
  String get onbRestoreChecksum;

  /// No description provided for @onbRestoreQrStub.
  ///
  /// In ru, this message translates to:
  /// **'Перенос с другого устройства появится в фазе 7. Пока войдите по секретной фразе.'**
  String get onbRestoreQrStub;

  /// No description provided for @onbDoneTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль готов'**
  String get onbDoneTitle;

  /// No description provided for @onbDoneText.
  ///
  /// In ru, this message translates to:
  /// **'Ключ сохранён на этом устройстве. Секретная фраза — ваша страховка, держите её в надёжном месте.'**
  String get onbDoneText;

  /// No description provided for @onbDoneRestoredText.
  ///
  /// In ru, this message translates to:
  /// **'Профиль восстановлен на этом устройстве. Имя и аватар подтянутся с сервера, когда вы к нему подключитесь.'**
  String get onbDoneRestoredText;

  /// No description provided for @onbDoneOpen.
  ///
  /// In ru, this message translates to:
  /// **'Открыть YeenLink'**
  String get onbDoneOpen;

  /// No description provided for @onbDoneRestart.
  ///
  /// In ru, this message translates to:
  /// **'Начать заново'**
  String get onbDoneRestart;

  /// No description provided for @deviceNameComputer.
  ///
  /// In ru, this message translates to:
  /// **'Компьютер · {os}'**
  String deviceNameComputer(String os);

  /// No description provided for @deviceNamePhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон · {model}'**
  String deviceNamePhone(String model);

  /// No description provided for @deviceNamePhoneUnknown.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get deviceNamePhoneUnknown;

  /// No description provided for @homeProfileRestored.
  ///
  /// In ru, this message translates to:
  /// **'Профиль восстановлен'**
  String get homeProfileRestored;

  /// No description provided for @homeFingerprint.
  ///
  /// In ru, this message translates to:
  /// **'Отпечаток ключа'**
  String get homeFingerprint;

  /// No description provided for @homeDevice.
  ///
  /// In ru, this message translates to:
  /// **'Это устройство'**
  String get homeDevice;

  /// No description provided for @homeNoServers.
  ///
  /// In ru, this message translates to:
  /// **'Серверов пока нет: подключение появится в фазе 2.'**
  String get homeNoServers;

  /// No description provided for @homeLoadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не получилось прочитать профиль на этом устройстве: {reason}'**
  String homeLoadFailed(String reason);

  /// No description provided for @onbRestoreEnterPhrase.
  ///
  /// In ru, this message translates to:
  /// **'Введите 12 слов'**
  String get onbRestoreEnterPhrase;

  /// No description provided for @onbPinEnterTwice.
  ///
  /// In ru, this message translates to:
  /// **'Введите PIN дважды'**
  String get onbPinEnterTwice;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return L10nRu();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
