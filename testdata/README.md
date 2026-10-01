# Тестовые векторы

Общие для Go и Dart: одни и те же файлы проверяют `server/pkg/codec` и
`client/test/core/codec`.

`vectors/codec/<имя>.cbor` — байты кадра, `<имя>.json` — ожидание:

```json
{ "description": "…", "valid": true, "canonical": true, "frame": { …отладочный JSON… } }
{ "description": "…", "valid": false, "canonical": false, "error": "dup_key" }
```

- `valid` — кадр должен разобраться; иначе разбор падает с категорией `error`
  (список категорий — `spec/README.md`).
- `canonical` — байты совпадают с детерминированным кодированием значения;
  такие кадры обе реализации обязаны перекодировать байт в байт.

Векторы генерирует `make vectors` (`server/internal/vectorgen`); править файлы
руками не нужно — CI сверяет их с генератором.
