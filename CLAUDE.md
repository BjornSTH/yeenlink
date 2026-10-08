# YeenLink

Self-hosted мессенджер с текстом, голосом и стримами: свой сервер на дешёвом VPS (1 ядро, 1–2 ГБ), профиль на ключах Ed25519, без центрального сервера. Сервер — Go, клиент — Flutter (Windows, Linux, Android, затем macOS), голос и видео — LiveKit.

## Где что лежит

- `docs/spec.md` — техническая спецификация: форматы, протокол, права, соединение, стримы, режим стримера, боты и модули, **фазы разработки с критериями «Готово, когда»**. Главный источник правды.
- `docs/design/` — дизайн-система: `tokens.json` (цвета двух тем, шрифты, отступы, скругления, тени, размеры), `README.md` (правила), `components/*` (правила и превью базовых виджетов), логотип.
- `docs/mockups/` — исходники всех экранов (`src/`), указатель `README.md` и PDF с экранами по фазам (`phases/phase-N.pdf`, большие фазы разбиты на `-pc` и `-android`).
- `server/` — Go-сервер. `client/` — Flutter-клиент. `spec/` — CDDL-схемы CBOR и профиль кодека (`spec/README.md`). `testdata/vectors/` — общие тестовые векторы.
- `project.yaml` — открытые решения (домен, лицензия, id приложения, путь Go-модуля). `null` — не решено: не выдумывай значение, спроси.
- `tools/` — запуск Flutter в Docker (`flutter-docker.sh`), если локального SDK нет.

### Устройство кода

- `server/pkg/codec` — CBOR (fxamacker/cbor) + отладочный JSON, `Frame`. `server/cmd/yl-decode` — CBOR из логов в JSON. `server/internal/vectorgen` — генератор векторов.
- Сервер (фаза 2, детали — `spec/server.md`, `spec/auth.md`): `server/cmd/ylsrv` — `init` (под root ставит службу systemd, шаблон `ylsrv.service`), `run`, `admin-token`, `check-ports`. `server/pkg/protocol` — вход (server_sig с хешем сертификата TLS, auth), кадры ready/resumed. `server/internal/`: `config` (TOML), `serverkey`, `admintoken`, `store` (SQLite modernc, миграции `migrations/NNNN_*.sql`, эталон `testdata/schema.sql`), `tlsmode` (acme/file/self-signed/proxy, хеш сертификата соединения), `server` (/ws, /.well-known/yeenlink, сессии и resume, admin.claim), `firstrun` (порты), `testclient`. `server/cmd/yl-smoke` — вход и admin.claim против живого сервера.
- `client/lib/core/codec` — тот же профиль на Dart (`cbor` + строгая проверка `strict.dart`). `client/lib/core/redact.dart` — `redact()` и `RedactedText`.
- `client/lib/ui/theme/tokens.g.dart` — **генерируется**, руками не править. `yl_theme.dart` — `ylTheme(Brightness)`.
- `client/lib/ui/widgets/` — 9 базовых виджетов `Yl*` и `YlSurface`; Material разрешён только здесь. `client/lib/showcase/` — витрина.
- `client/lib/l10n/app_ru.arb` — все строки интерфейса; `lib/l10n/gen/` генерируется.
- Личность (фаза 1, детали — `spec/identity.md`): `server/pkg/identity` и `client/lib/core/identity` — BIP39, SLIP-0010 (`m/22860'/0'/i'`), отпечатки, конверт `Signed`, payload с проверкой полей. `client/lib/core/vault` — `KeyVault` (системное / в памяти / файл для отладки) и блоб главного ключа под PIN. `client/lib/core/account` — `AccountStore` (создание, восстановление, разблокировка), `PinGuard`, аватар, мост к платформе (Android — `MainActivity.kt`, канал `yeenlink/platform`).
- `client/lib/features/onboarding/` — первый вход: контроллер без виджетов и экран. `client/lib/app/app.dart` — запуск: онбординг или главное окно.
- Клиент фазы 2: `core/net` — `ServerAddress` (`host:port#ОТПЕЧАТОК`), `ServerLink` (TLS принимает любой сертификат, но проверяет server_sig по его хешу). `core/protocol/messages.dart` — ready и события. `core/db` — drift (`app_db.dart`, `app_db.g.dart` генерируется). `core/servers` — `ServerConnection` (переподключение с resume), `ServersController`. `core/account/account_sync.dart` — сверка профиля и списка устройств, `MasterKeyCache`. `features/home/` — главное окно (ПК и телефон), добавление сервера, ключ администратора, PIN.
- `client/lib/ui/theme/pending_tokens.dart` — **временные** размеры, которых нет в tokens.json; после выгрузки заменить на `YlSize` и удалить.
- `client/lib/ui/icons/` — иконки как пути SVG из макетов. `client/lib/ui/illustrations/` — декоративные иллюстрации: там координаты и размеры числами разрешены (check_rules их не проверяет), цвета — всё равно только из токенов.
- `client/integration_test/` — проверка на настоящей платформе: подписи Go ↔ Dart, системное хранилище, замер KDF.

### Токены дизайн-системы

`docs/design/tokens.json` — выгрузка из дизайн-системы, руками не правится; это единственный источник для `tokens.g.dart`. Генератор падает на незнакомой группе верхнего уровня — тогда добавь её в `knownGroups` и в генерацию (`client/tool/gen_tokens.dart`). Нужного значения нет в токенах — не пиши число в виджете, а спроси, чтобы его добавили в дизайн-систему. После новой выгрузки: `make gen`, `make ci`, изменения golden-снимков проверь глазами.

## Как работать

1. В начале сессии прочитай этот файл, затем в `docs/spec.md` раздел текущей фазы и разделы, на которые он ссылается.
2. Перед экраном открой его исходник и скриншот из `docs/mockups/` (по указателю). Значения бери из исходника, цвета и размеры переводи в токены.
3. Протокол и криптографию начинай с тестов: векторы в `testdata/vectors/` должны проходить и в Go, и в Dart.
4. Фаза закрыта, только когда выполнены её критерии «Готово, когда» из спецификации.
5. Если спецификация и макет расходятся — права спецификация; отметь расхождение в ответе.

## Правила, которые нельзя нарушать

- **Кодек:** весь обмен кадрами — CBOR через общий пакет кодека (`server/pkg/codec`, `client/lib/core/codec`). JSON — только отладочный режим `--codec=json`.
- **Подписи:** подписывается байтовый payload конверта `Signed`; payload никогда не пересобирается после подписи.
- **Права** считает только сервер и присылает готовыми (`perms.update`). Клиент лишь прячет недоступное.
- **Ключи:** главный ключ хранится зашифрованным в системном хранилище и разблокируется PIN-кодом; для обычной работы — ключ устройства.
- **Идентификаторы** (названия серверов, адреса, IP, порты, отпечатки ключей, handle, приглашения) в интерфейсе выводятся только через `redact(kind, value)` — иначе режим стримера протечёт.
- **Цвета, шрифты, отступы** — только из сгенерированных `YlColors`, `YlShadows`, `YlText`, `YlSpace`, `YlRadius`, `YlSize`, `YlOpacity` (генерируются из `docs/design/tokens.json`). Никаких hex в виджетах. Проверяет `client/tool/check_rules.dart`.
- **Material-виджеты** не используются как есть — только через свои обёртки (`YlButton`, `YlToggle` и т. д.).
- **Плагинов с кодом на клиенте нет.** Расширения — темы (данные), боты (API), модули (WASM на сервере).
- **Тексты интерфейса** — на русском, на «вы», коротко и честно (тон — в `docs/design/README.md`); все строки через файлы локализации.
- **Голос важнее стрима:** при перегрузке канала сначала режется стрим.

## Команды

Из корня. Flutter, если его нет в PATH, запускается через Docker-образ той же версии, что в CI (`client/.flutter-version`).

- `make ci` — всё, что делает CI: линтеры, тесты, сверка сгенерированного.
- `make test` — тесты сервера (`go test -race ./...`) и клиента (`flutter test`: кодек на векторах, виджеты, golden-снимки витрины).
- `make lint` — `go vet`, `golangci-lint run`, `flutter analyze --fatal-infos`, `dart format`, `dart run tool/check_rules.dart`.
- `make gen` — токены (`dart run tool/gen_tokens.dart`), локализация (`flutter gen-l10n`), таблицы drift (`dart run build_runner build` + формат 100), векторы (`go run ./internal/vectorgen`). Сгенерированное коммитится; `make check-gen` сверяет.
- `make goldens` — обновить golden-снимки витрины (только Linux).
- `make fmt` — `gofmt` и `dart format`.
- `make showcase` — витрина компонентов в окне (нужен локальный Flutter): `flutter run -d linux -t lib/main_showcase.dart`.
- Сервер: `ylsrv init [--non-interactive --name … --host … --listen … --tls acme|file|self-signed|proxy --data-dir … --config …]`, затем `ylsrv run [--config …] [--codec=json]`; `ylsrv admin-token`, `ylsrv check-ports`. `go run ./cmd/yl-decode [--in auto|raw|hex|base64] [файл]`.
- `make build-server` — статические бинарники в `server/bin/` (нужны живым тестам клиента, tag `live`; без бинарника они пропускаются).
- `make vps-smoke` (`tools/vps-smoke.sh`) — установка на чистый Debian 12 с systemd в Docker: `sudo ylsrv init`, служба, вход, admin.claim, права 0600, ключ не в журнале, RSS.
- Проверка живого сервера: `go run ./cmd/yl-smoke --url https://host:port --token-file …/admin-token [--expect-key ОТПЕЧАТОК]`.
- Flutter без локального SDK: `cd client && ../tools/flutter-docker.sh flutter <команда>` (там же собирается APK: `flutter build apk --debug`).
- Интеграционный тест на платформе: `cd client && flutter test integration_test -d linux|windows|<android>`. В CI — `.github/workflows/platforms.yml`: на PR в `main` и вручную (Windows, Linux с gnome-keyring, эмулятор Android); на каждый push — только `ci.yml` на Ubuntu.
- Отладка без системного хранилища (Docker, Linux без secret service): `flutter run --dart-define=YL_VAULT=file` — ключи в незашифрованном файле, только debug.
- Замер Argon2id: `flutter test --run-skipped -t bench test/core/vault`.
