# YeenLink — общие команды. Всё, что делает CI, — make ci.
#
# Flutter: если его нет в PATH, команды клиента идут через Docker-образ той же
# версии, что в CI (tools/flutter-docker.sh, версия — client/.flutter-version).

SHELL := /bin/bash

ifeq ($(shell command -v flutter 2>/dev/null),)
  FLUTTER_RUN := ../tools/flutter-docker.sh
else
  FLUTTER_RUN :=
endif

GOLANGCI := $(or $(shell command -v golangci-lint 2>/dev/null),$(shell go env GOPATH)/bin/golangci-lint)

# Сгенерированное, что лежит в репозитории и сверяется в CI.
GENERATED := client/lib/ui/theme/tokens.g.dart client/lib/l10n/gen testdata/vectors

.PHONY: all ci test test-server test-client lint lint-server lint-client \
        gen gen-tokens gen-l10n vectors check-gen goldens showcase build-server fmt

all: ci

ci: lint test check-gen

# --- тесты -------------------------------------------------------------------

test: test-server test-client

test-server:
	cd server && go test -race ./...

test-client:
	cd client && $(FLUTTER_RUN) flutter test

# Обновить golden-снимки витрины (только на Linux; см. client/dart_test.yaml).
goldens:
	cd client && $(FLUTTER_RUN) flutter test --update-goldens --tags golden

# --- линтеры -----------------------------------------------------------------

lint: lint-server lint-client

lint-server:
	cd server && go vet ./... && $(GOLANGCI) run ./...

lint-client:
	cd client && $(FLUTTER_RUN) sh -c '\
		flutter analyze --fatal-infos && \
		dart format --page-width 100 --output=none --set-exit-if-changed lib/ui lib/core lib/showcase lib/main.dart lib/main_showcase.dart test tool && \
		dart run tool/check_rules.dart'

fmt:
	cd server && gofmt -w .
	cd client && $(FLUTTER_RUN) dart format --page-width 100 lib/ui lib/core lib/showcase lib/main.dart lib/main_showcase.dart test tool

# --- генерация ---------------------------------------------------------------

gen: gen-tokens gen-l10n vectors

# YlColors, YlShadows, YlText, YlSpace, YlRadius, YlSize, YlOpacity из docs/design/tokens.json.
gen-tokens:
	cd client && $(FLUTTER_RUN) dart run tool/gen_tokens.dart

gen-l10n:
	cd client && $(FLUTTER_RUN) flutter gen-l10n

# Общие тестовые векторы кодека: testdata/vectors/codec.
vectors:
	cd server && go run ./internal/vectorgen -out ../testdata/vectors/codec

# Сгенерированные файлы должны совпадать с тем, что в репозитории.
check-gen: gen
	@git add -N $(GENERATED) 2>/dev/null || true
	@git diff --exit-code --stat -- $(GENERATED) || \
		{ echo "Сгенерированные файлы устарели: выполните make gen и закоммитьте."; exit 1; }

# --- запуск ------------------------------------------------------------------

# Витрина компонентов в окне — нужен локальный Flutter (Docker окно не покажет).
showcase:
	cd client && flutter run -d linux -t lib/main_showcase.dart

build-server:
	cd server && go build -o bin/ ./cmd/...
