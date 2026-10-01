# Образ для локального запуска flutter без установки SDK (tools/flutter-docker.sh).
# Та же версия, что в CI; SDK открыт на запись, чтобы работать не от root.
ARG FLUTTER_VERSION
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION}
RUN chmod -R a+rwX /sdks/flutter \
 && git config --system --add safe.directory '*' \
 && mkdir -p /cache /tmp/home && chmod 1777 /cache /tmp/home
