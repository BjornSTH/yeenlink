# Макеты YeenLink — указатель

Исходники экранов с холста. Каждый файл — один экран или компонент. Откройте `src/<группа>/<файл>`.

Как читать файл `.dc.html`:

- Разметка внутри `<x-dc>` — экран; **точные значения** (отступы, размеры, цвета, тексты) лежат в inline-стилях.
- `{{имя}}` — данные или вычисленное значение из `renderVals()` в `<script>` внизу файла; там же логика состояний и обработчики кликов.
- `<sc-if value="{{x}}">` — блок показывается при условии; `<sc-for list="{{xs}}" as="x">` — список.
- `<dc-import name="X" …>` — вложенный компонент из файла `X.dc.html` с параметрами; файлы-«обёртки» показывают другой экран в определённом состоянии (`start="card"`, `section="voice"` и т. п.).
- Цвета записаны hex-значениями; соответствие токенам — в `../design/tokens.json` (тёмная тема — колонка `dark`). В коде используйте токены, а не hex.
- Файлы не запускаются сами по себе: им нужна среда холста. Берите из них значения и структуру, а внешний вид сверяйте со скриншотами.

| Группа | Файл | Что это | Использует |
| --- | --- | --- | --- |
| 01-main | `AdminClaim.dc.html` | Ключ администратора — ПК | Main |
| 01-main | `Conn-failover.dc.html` | Соединение: Работает через запасной адрес | Main |
| 01-main | `Conn-offline.dc.html` | Соединение: Сервер недоступен | Main |
| 01-main | `Conn-reconnecting.dc.html` | Соединение: Связь потеряна — переключение | Main |
| 01-main | `EmptyServers.dc.html` | Нет серверов — ПК | — |
| 01-main | `LightCard.dc.html` | Светлая тема — карточка участника | MainLight |
| 01-main | `LightPage.dc.html` | Светлая тема — страница со стеной | MainLight |
| 01-main | `Main.dc.html` | Главный экран — список участников (кликабельный) | ProfilePanel |
| 01-main | `MainLight.dc.html` | Светлая тема — главный экран (кликабельный) | ProfilePanelLight |
| 01-main | `MainSlash.dc.html` | Слэш-команды в поле ввода | Main |
| 01-main | `MainStreamer.dc.html` | Режим стримера — главный экран | Main |
| 01-main | `MainStreamerCard.dc.html` | Режим стримера — карточка участника | Main |
| 01-main | `Overlay.dc.html` | «Открыть страницу» — панель со стеной | Main |
| 01-main | `Popover.dc.html` | Клик по участнику — карточка | Main |
| 01-main | `PostComposer.dc.html` | Новый пост на стене — ПК | Main |
| 01-main | `ProfilePanel.dc.html` | Компонент: панель профиля | — |
| 01-main | `ProfilePanelLight.dc.html` | Компонент: панель профиля, светлая | — |
| 02-voice | `Voice.dc.html` | Голосовой канал — превью эфира (кликабельный) | — |
| 02-voice | `VoiceCritical.dc.html` | Стрим: остановка через 8 с (95%) | Voice |
| 02-voice | `VoiceDevices.dc.html` | Демонстрация — камеры и устройства | Voice |
| 02-voice | `VoiceOverload.dc.html` | Стрим: сервер на пределе (85%) | Voice |
| 02-voice | `VoicePicker.dc.html` | Демонстрация — режим, разрешение до 1440p, до 144 кадров | Voice |
| 02-voice | `VoiceWatch.dc.html` | Просмотр эфира (после «Подключиться») | Voice |
| 03-onboarding | `OnbSteps.dc.html` | Компонент: шаги первого входа | — |
| 03-onboarding | `Onboarding.dc.html` | Первый вход — ПК | OnbSteps |
| 03-onboarding | `OnboardingPhone.dc.html` | Первый вход — Android | OnbSteps |
| 04-settings | `LinkDevice-confirm.dc.html` | Привязка устройства: подтверждение — ПК | LinkDevice |
| 04-settings | `LinkDevice.dc.html` | Привязка устройства: QR — ПК | Settings |
| 04-settings | `Set-appearance.dc.html` | Настройки ПК — Внешний вид | Settings |
| 04-settings | `Set-keybinds.dc.html` | Настройки ПК — Горячие клавиши | Settings |
| 04-settings | `Set-language.dc.html` | Настройки ПК — Язык | Settings |
| 04-settings | `Set-notifications.dc.html` | Настройки ПК — Уведомления | Settings |
| 04-settings | `Set-security.dc.html` | Настройки ПК — Безопасность и устройства | Settings |
| 04-settings | `Set-streamer.dc.html` | Настройки — Режим стримера | Settings |
| 04-settings | `Set-voice.dc.html` | Настройки ПК — Голос и видео | Settings |
| 04-settings | `SetPhone-appearance.dc.html` | Android — Внешний вид | SettingsPhone |
| 04-settings | `SetPhone-language.dc.html` | Android — Язык | SettingsPhone |
| 04-settings | `SetPhone-notifications.dc.html` | Android — Уведомления | SettingsPhone |
| 04-settings | `SetPhone-profile.dc.html` | Android — Профиль | SettingsPhone |
| 04-settings | `SetPhone-security.dc.html` | Android — Безопасность и устройства | SettingsPhone |
| 04-settings | `SetPhone-voice.dc.html` | Android — Голос и видео | SettingsPhone |
| 04-settings | `Settings.dc.html` | Настройки — ПК | Main, SettingsSection |
| 04-settings | `SettingsPhone.dc.html` | Настройки — Android | SettingsSection |
| 04-settings | `SettingsPhoneLight.dc.html` | Android · Светлая — настройки | SettingsSectionLight |
| 04-settings | `SettingsSection.dc.html` | Компонент: разделы настроек | — |
| 04-settings | `SettingsSectionLight.dc.html` | Компонент: разделы настроек, светлая | — |
| 05-server-admin | `AdminClaimPhone.dc.html` | Ключ администратора — Android | — |
| 05-server-admin | `InviteCreate.dc.html` | Создание приглашения — ПК | Main |
| 05-server-admin | `ServerSection.dc.html` | Компонент: разделы настроек сервера | — |
| 05-server-admin | `ServerSettings.dc.html` | Настройки сервера — Обзор (кликабельный) | Main, ServerSection |
| 05-server-admin | `ServerSettingsPhone.dc.html` | Настройки сервера — Android | ServerSection |
| 05-server-admin | `Srv-bots.dc.html` | Настройки сервера — Боты и вебхуки | ServerSettings |
| 05-server-admin | `Srv-channels.dc.html` | Сервер ПК — Каналы | ServerSettings |
| 05-server-admin | `Srv-invites.dc.html` | Сервер ПК — Приглашения | ServerSettings |
| 05-server-admin | `Srv-limits.dc.html` | Сервер ПК — Лимиты и ресурсы | ServerSettings |
| 05-server-admin | `Srv-members.dc.html` | Сервер ПК — Участники | ServerSettings |
| 05-server-admin | `Srv-moderation.dc.html` | Сервер ПК — Модерация | ServerSettings |
| 05-server-admin | `Srv-network.dc.html` | Сервер ПК — Адреса и соединение | ServerSettings |
| 05-server-admin | `Srv-roles.dc.html` | Сервер ПК — Роли и права | ServerSettings |
| 05-server-admin | `SrvPhone-bots.dc.html` | Android — Боты и вебхуки | ServerSettingsPhone |
| 05-server-admin | `SrvPhone-limits.dc.html` | Сервер Android — Лимиты и ресурсы | ServerSettingsPhone |
| 05-server-admin | `SrvPhone-members.dc.html` | Сервер Android — Участники | ServerSettingsPhone |
| 05-server-admin | `SrvPhone-network.dc.html` | Сервер Android — Адреса и соединение | ServerSettingsPhone |
| 06-invite | `InviteJoin.dc.html` | Вход по приглашению — ПК | Main |
| 07-discovery | `Discovery-detail.dc.html` | Сервер из каталога, по заявке — ПК | Discovery |
| 07-discovery | `Discovery.dc.html` | Каталог серверов — ПК (кликабельный) | — |
| 07-discovery | `MobileDiscover-detail.dc.html` | Сервер из каталога — Android | MobileDiscover |
| 07-discovery | `MobileDiscover.dc.html` | Каталог — Android | — |
| 07-discovery | `MobileDiscoverLight.dc.html` | Android · Светлая — каталог | — |
| 08-android | `Mobile-chat.dc.html` | Android — чат канала | MobileApp |
| 08-android | `Mobile-dm.dc.html` | Android — личный чат | MobileApp |
| 08-android | `Mobile-dms.dc.html` | Android — личные сообщения | MobileApp |
| 08-android | `Mobile-invite.dc.html` | Вход по приглашению — Android | MobileApp |
| 08-android | `Mobile-offline.dc.html` | Нет связи — Android | MobileApp |
| 08-android | `Mobile-sheet.dc.html` | Android — карточка участника | MobileApp |
| 08-android | `Mobile-voice.dc.html` | Android — голосовой канал | MobileApp |
| 08-android | `Mobile-watch.dc.html` | Android — просмотр эфира | MobileApp |
| 08-android | `MobileApp.dc.html` | Android — серверы и каналы (кликабельный) | — |
| 08-android | `MobileAppLight.dc.html` | Android · Светлая — серверы и каналы | — |
| 08-android | `MobileEmpty.dc.html` | Нет серверов — Android | — |
| 08-android | `MobileFeed-compose.dc.html` | Новый пост — Android | MobileFeed |
| 08-android | `MobileFeed.dc.html` | Лента — Android (кликабельная) | — |
| 08-android | `MobileFeedLight.dc.html` | Android · Светлая — лента | — |
| 08-android | `MobileLight-chat.dc.html` | Android · Светлая — чат | MobileAppLight |
| 08-android | `MobileLight-dms.dc.html` | Android · Светлая — личные | MobileAppLight |
| 08-android | `MobileLight-sheet.dc.html` | Android · Светлая — карточка участника | MobileAppLight |
| 08-android | `MobileLight-voice.dc.html` | Android · Светлая — голосовой канал | MobileAppLight |
| 08-android | `Phone.dc.html` | Android — страничка профиля | — |
| 08-android | `PhoneLight.dc.html` | Android · Светлая — профиль | — |
