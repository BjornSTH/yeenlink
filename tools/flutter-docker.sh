#!/usr/bin/env bash
# Запускает flutter/dart в Docker-образе той же версии, что в CI, когда
# локального Flutter нет. Пример: tools/flutter-docker.sh flutter test
# Рабочая папка внутри — client/ (или подпапка, если вызвано из неё).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(cat "$root/client/.flutter-version")"
image="yeenlink-flutter:$version"
if ! docker image inspect "$image" >/dev/null 2>&1; then
  docker build -q -t "$image" --build-arg FLUTTER_VERSION="$version" \
    -f "$root/tools/flutter.Dockerfile" "$root/tools" >&2
fi
rel="${PWD#"$root"}"
case "$PWD" in "$root"*) workdir="/w$rel" ;; *) workdir="/w/client" ;; esac
[ "$workdir" = "/w" ] && workdir="/w/client"
tty=(); [ -t 1 ] && tty=(-t)
exec docker run --rm -i "${tty[@]}" \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp/home -e PUB_CACHE=/cache/pub -e FLUTTER_SUPPRESS_ANALYTICS=true \
  -v yeenlink-pub-cache:/cache \
  -v "$root:/w" -w "$workdir" \
  "$image" "$@"
