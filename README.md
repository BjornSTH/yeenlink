# YeenLink

Self-hosted мессенджер с текстом, голосом и стримами: свой сервер на дешёвом VPS,
профиль на ключах Ed25519, без центрального сервера. Сервер — Go, клиент — Flutter.

- Спецификация и фазы разработки: [docs/spec.md](docs/spec.md)
- Дизайн-система: [docs/design/](docs/design/README.md), макеты: [docs/mockups/](docs/mockups/README.md)
- Профиль CBOR и схемы: [spec/](spec/README.md)
- Как работать с репозиторием и команды: [CLAUDE.md](CLAUDE.md)

Быстрый старт: `make ci` — линтеры и тесты сервера и клиента. Без локального Flutter
команды клиента идут через Docker.

Лицензия ещё не выбрана (см. `project.yaml`).
