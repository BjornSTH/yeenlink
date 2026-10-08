# Вход на сервер и сессия

Детали к разделам `docs/spec.md` «Вход на сервер (challenge–response)», «Протокол
клиент–сервер» и «Владелец и ключ администратора». Реализации:
`server/pkg/protocol` и `server/internal/server` (Go),
`client/lib/core/protocol` (Dart). Векторы: `testdata/vectors/auth/auth.json`
(генерирует `make vectors`), формы кадров — `spec/auth.cddl`.

## Порядок

```
клиент                                            сервер
  GET /.well-known/yeenlink  ─────────────────▶
                             ◀─────────────────   Signed{t = "server_info"}
  сверить server_pub с закреплённым (или спросить, см. «Первый контакт»)

  WebSocket /ws
  hello {proto, master_pub, device_pub, device_cert, client_nonce, resume?}  ──▶
                             ◀──  challenge {nonce, server_pub, ts, server_sig, alt_sigs?, unbound?}
  проверить server_sig по хешу сертификата, который видит сам
  auth {sig}  ────────────────────────────────▶
                             ◀──  ready {…}  или  resumed {…}
```

`hello` и `auth` — запросы с `id`; `challenge`, `ready` и `resumed` — ответы
на них с тем же `id`. До `ready`/`resumed` сервер принимает только эти два кадра:
любой другой — ошибка `not_authenticated` и закрытие.

## server_info

`GET /.well-known/yeenlink` отдаёт CBOR конверта `Signed` (`application/cbor`;
с `?json` — отладочный JSON). Тип `server_info` подписывает ключ сервера:

```
server_info = {v: 1, server_pub: bstr .size 32, name: tstr, version: tstr}
```

- `k` конверта обязан совпадать с `server_pub` (`OpenServerInfo` /
  `openServerInfo`, иначе `signer_mismatch`).
- `name` — текст по правилам `spec/identity.md` («Поля»), 1–64 кодовых точки.
- `version` — версия сборки `ylsrv`, только для показа.

Подпись server_info доказывает лишь, что ответ дал владелец ключа; защиту от
подмены при первом контакте даёт только сверка отпечатка (ниже).

## Подписываемые байты

Склейка без разделителей, как у `Signed`; целые — 8 байт big-endian.

```
server_sig = Ed25519(server_key, "yl-server-v1" | client_nonce | nonce | ts | cert_hash)
auth.sig   = Ed25519(device_key, "yl-auth-v1"   | nonce | server_pub | ts)
cert_hash  = SHA-256(DER листового сертификата TLS этого соединения)
```

`client_nonce` и `nonce` — по 32 случайных байта; `ts` — время сервера в мс.

### Какой сертификат подписывается

| Режим `tls.mode` | `cert_hash` |
| --- | --- |
| `acme`, `file`, `self-signed` | хеш сертификата, который сервер отдал **в этом** соединении (запоминается в `GetCertificate`) |
| `proxy` с `tls.proxy_cert` | хеши всех сертификатов прокси: первый — в `server_sig`, остальные — в `alt_sigs [{h, s}]` |
| `proxy` без `tls.proxy_cert` | неизвестен: `unbound: true`, подпись по 32 нулевым байтам |

Клиент принимает challenge, если:

1. `server_pub` равен закреплённому — иначе «это не тот сервер» (`wrong_server`);
2. при `unbound` — подпись по нулевому хешу сходится; вход разрешён, но клиент
   показывает предупреждение «соединение не защищено от подмены сертификата»;
3. иначе хеш сертификата, который клиент **сам** видит в своём TLS-соединении,
   подписан в `server_sig` или в одной из `alt_sigs` — иначе `cert_not_signed`
   (это и есть признак посредника), соединение рвётся.

Без TLS (отладка на `ws://`) клиент видит хеш `nil` и получает `cert_not_signed`,
если сервер не прислал `unbound`.

### Сервер проверяет

- `hello`: `proto` = 1 (иначе `proto`); ключи и `client_nonce` нужной длины
  (`bad_frame`); `device_cert` — конверт `device_cert`, подписанный `master_pub`,
  и его `device_pub` равен `hello.device_pub` (`bad_cert`); устройство не в
  `revoked_devices` (`device_revoked`).
- `auth`: прошло не больше 30 000 мс от `ts` (`challenge_expired`), подпись
  устройства сходится (`bad_sig`). `nonce` одноразовый: на одно соединение —
  один challenge.

Сервер пускает по действительному сертификату устройства и отсутствию в
отозванных; поле `active` списка устройств — справочное. В фазе 2 пускаются
все вошедшие; одобрение новичков — с фазы 4.

## Первый контакт и отпечаток

Ключ сервера закрепляется при первом удачном входе. Добавляя сервер по адресу,
клиент показывает **полный** отпечаток `server_pub` (четыре группы, как в
`spec/identity.md`) и просит сверить его с выводом `ylsrv init`. Адрес вида
`host:port#XXXX·XXXX·XXXX·XXXX` (разделитель групп — `·` или `:`, регистр не
важен) закрепляет ключ сразу, без вопроса; несовпадение — «это не тот сервер».

## ready

```
ready = {
  server:  {pub, name, version, has_owner, info},   ; info — байты Signed server_info
  me:      {master_pub, owner, profile?, devices?},  ; последние принятые сервером Signed
  session: {id: bstr .size 16, resume_ms: 300000},
  channels: [], roles: [role], perms: {server, channels: {}}, addresses: [],
  last_event: uint,
}
role = {id, name, position, perms, builtin?}   ; builtin: "everyone" | "owner"
```

- `channels` и `addresses` в фазе 2 пустые; формы — в фазах 3 и 4.
- **Маски прав** (`role.perms`, `perms.server`, `perms.channels[*]`) — `uint64`
  по смыслу, но в кадре это `int64` в дополнительном коде: бит 63 (`OWNER`) иначе
  не помещается в целые профиля CBOR. Перевод — `PermsToWire`/`PermsFromWire` в
  Go; в Dart 64-битный `int` хранит те же биты, проверка бита —
  `mask & (1 << n) != 0`.
  Владелец получает `perms.server = -1` (все биты).
- `me.profile` пуст, пока клиент не прислал `profile.push`; `devices` — до
  первого `devices.push`.

## Сессия и resume

- После `ready` сервер держит сессию: `id`, главный ключ, ключ устройства.
  События (`server.update`, `member.update`, …) нумеруются по порядку; номер
  последнего отданного — `last_event` в `ready`/`resumed`.
- Обрыв → клиент снова проходит `hello` с `resume {session, last_event}`. Если
  сессия жива (меньше 5 минут с обрыва), принадлежит тому же главному ключу
  **и** тому же устройству, а все события после `last_event` ещё в кольце —
  ответ `resumed {session, events, last_event}`, где `events` — CBOR кадров
  событий по порядку. Иначе — обычный `ready` с новой сессией.
- Чужой или украденный `session` ничего не даёт: проверка подписи идёт до
  resume, а сессия чужого ключа просто не находится.
- Если сессию продолжили в новом соединении, старое закрывается с `replaced`.
- Сессии и кольцо событий живут в памяти: после перезапуска сервера — `ready`.

## Ключ администратора

`admin.claim {token}` — любому вошедшему. Ответ `{owner: true}`, затем всем
событие `server.update` (`has_owner: true`) и `member.update` нового (и
прежнего, если был) владельца.

- Попыток — 5 в минуту на адрес клиента (`X-Forwarded-For` учитывается только
  от `trusted_proxies`). Шестая — `rate_limited`, даже с верным ключом.
- Не тот формат или ключ не подошёл — `bad_token`. Ключ одноразовый: после
  успеха его хеш помечается использованным, файл удаляется.
- Новый ключ `ylsrv admin-token` отменяет прежний неиспользованный; его
  применение передаёт роль Владельца новому главному ключу, прежний её теряет.
  Смена — запись `owner.change` в `server_log` и строка в журнале демона
  (отпечатки, без ключа).

## Профиль и устройства

| Запрос | `d` | Ответ | Проверки |
| --- | --- | --- | --- |
| `profile.push` | `{profile}` — байты `Signed` `profile` | `{seq}` | `profile.master` = главный ключ сессии; `seq` больше хранимого, иначе `stale` |
| `devices.push` | `{devices}` — `Signed` `devices` | `{seq}` | подписан главным ключом сессии; `seq` больше; `revoked` попадают в отозванные и рвут их сессии |
| `revoke.push` | `{revoke}` — `Signed` `revoke` | `{}` | подписан главным ключом сессии; сессии устройства рвутся с `device_revoked` |

После `profile.push` всем уходит `member.update {master_pub, owner, profile}`.

Клиент после восстановления по фразе впервые подключается с `profile` и
`devices` с `seq` 0; когда на сервере уже лежит версия с бо́льшим `seq` — сервер
отвечает `stale` с текущим `seq` в `msg`, клиент берёт её из `ready.me` и
подписывает следующую (для `devices` — после ввода PIN, если главный ключ не
остался в памяти с момента восстановления).

## Коды ошибок

| `e.code` | Когда | Соединение |
| --- | --- | --- |
| `proto` | другая версия протокола | закрывается |
| `bad_frame` | кадр не разобран, не тот тип сообщения WebSocket, длины в `hello` | закрывается |
| `bad_cert` | сертификат устройства не открылся | закрывается |
| `device_revoked` | устройство отозвано | закрывается |
| `bad_sig` | подпись `auth` не сошлась | закрывается |
| `challenge_expired` | `auth` позже 30 с | закрывается |
| `not_authenticated` | кадр не по порядку входа | закрывается |
| `replaced` | сессию продолжили в другом соединении | закрывается |
| `unknown_op` | операция не поддерживается | остаётся |
| `rate_limited` | лимит `admin.claim` | остаётся |
| `bad_token` | ключ администратора не подошёл | остаётся |
| `stale` | `seq` не больше хранимого | остаётся |
| `bad_payload` | `d` или подписанный конверт не прошли проверку | остаётся |

Закрывая соединение, сервер сначала шлёт кадр `{op: "error", e}` без `id`, затем
закрывает WebSocket с кодом 1008 и `code` в причине. Ошибка запроса с `id`
приходит ответом на этот `id`.

## Транспорт

- WebSocket `/ws`, `permessage-deflate`. В режиме `cbor` — бинарные сообщения,
  в `json` — текстовые; чужой тип — `bad_frame`.
- Кадр не больше 256 КиБ. Ping каждые 30 с; нет ответа на ping за 60 с — соединение
  закрывается.
