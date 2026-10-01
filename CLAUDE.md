# YeenLink

Self-hosted мессенджер с текстом, голосом и стримами: свой сервер на дешёвом VPS (1 ядро, 1–2 ГБ), профиль на ключах Ed25519, без центрального сервера. Сервер — Go, клиент — Flutter (Windows, Linux, Android, затем macOS), голос и видео — LiveKit.

## Где что лежит

- `docs/spec.md` — техническая спецификация: форматы, протокол, права, соединение, стримы, режим стримера, боты и модули, **фазы разработки с критериями «Готово, когда»**. Главный источник правды.
- `docs/design/` — дизайн-система: `tokens.json` (цвета двух тем, шрифты, отступы, скругления, тени, размеры), `README.md` (правила), `components/*` (правила и превью базовых виджетов), логотип.
- `docs/mockups/` — исходники всех экранов (`src/`), указатель `README.md` и PDF с экранами по фазам (`phases/phase-N.pdf`, большие фазы разбиты на `-pc` и `-android`).
- `server/` — Go-сервер. `client/` — Flutter-клиент. `spec/` — CDDL-схемы CBOR и профиль кодека (`spec/README.md`). `testdata/vectors/` — общие тестовые векторы.
- `project.yaml` — открытые решения (домен, лицензия, id приложения, путь Go-модуля). `null` — не решено: не выдумывай значение, спроси.
- `tools/` — запуск Flutter в Docker (`flutter-docker.sh`), если локального SDK нет.

### Устройство кода (фаза 0)

- `server/pkg/codec` — CBOR (fxamacker/cbor) + отладочный JSON, `Frame`. `server/cmd/yl-decode` — CBOR из логов в JSON. `server/cmd/ylsrv` — пока каркас. `server/internal/vectorgen` — генератор векторов.
- `client/lib/core/codec` — тот же профиль на Dart (`cbor` + строгая проверка `strict.dart`). `client/lib/core/redact.dart` — `redact()` и `RedactedText`.
- `client/lib/ui/theme/tokens.g.dart` — **генерируется**, руками не править. `yl_theme.dart` — `ylTheme(Brightness)`.
- `client/lib/ui/widgets/` — 9 базовых виджетов `Yl*` и `YlSurface`; Material разрешён только здесь. `client/lib/showcase/` — витрина.
- `client/lib/l10n/app_ru.arb` — все строки интерфейса; `lib/l10n/gen/` генерируется.

### Временное: `docs/design/tokens.local.json`

Значения из превью компонентов, которых нет в выгрузке дизайн-системы: палитра аватаров `avatar-1…4`, стили `button`, `badge`, `banner`, `mono-sm`, `mono-xs`, размеры компонентов (`YlMetrics`). Их перенесут в дизайн-систему. **После следующей выгрузки `tokens.json`:** проверь, что значения в ней есть, удали `tokens.local.json`, убери из `client/tool/gen_tokens.dart` константу `localTokensPath` и её чтение, при необходимости переименуй обращения `YlMetrics.*` на новые имена, затем `make gen` и `make test`.

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
- **Цвета, шрифты, отступы** — только из сгенерированных `YlColors`, `YlText`, `YlSpace`, `YlRadius`, `YlSize`, `YlMetrics` (генерируются из `docs/design/tokens.json`). Никаких hex в виджетах. Проверяет `client/tool/check_rules.dart`.
- **Material-виджеты** не используются как есть — только через свои обёртки (`YlButton`, `YlToggle` и т. д.).
- **Плагинов с кодом на клиенте нет.** Расширения — темы (данные), боты (API), модули (WASM на сервере).
- **Тексты интерфейса** — на русском, на «вы», коротко и честно (тон — в `docs/design/README.md`); все строки через файлы локализации.
- **Голос важнее стрима:** при перегрузке канала сначала режется стрим.

## Команды

Из корня. Flutter, если его нет в PATH, запускается через Docker-образ той же версии, что в CI (`client/.flutter-version`).

- `make ci` — всё, что делает CI: линтеры, тесты, сверка сгенерированного.
- `make test` — тесты сервера (`go test -race ./...`) и клиента (`flutter test`: кодек на векторах, виджеты, golden-снимки витрины).
- `make lint` — `go vet`, `golangci-lint run`, `flutter analyze --fatal-infos`, `dart format`, `dart run tool/check_rules.dart`.
- `make gen` — токены (`dart run tool/gen_tokens.dart`), локализация (`flutter gen-l10n`), векторы (`go run ./internal/vectorgen`). Сгенерированное коммитится; `make check-gen` сверяет.
- `make goldens` — обновить golden-снимки витрины (только Linux).
- `make fmt` — `gofmt` и `dart format`.
- `make showcase` — витрина компонентов в окне (нужен локальный Flutter): `flutter run -d linux -t lib/main_showcase.dart`.
- Сервер: `cd server && go run ./cmd/ylsrv [--codec=json]`; `go run ./cmd/yl-decode [--in auto|raw|hex|base64] [файл]`.
- Flutter без локального SDK: `cd client && ../tools/flutter-docker.sh flutter <команда>`.
