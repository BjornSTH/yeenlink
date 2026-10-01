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
