#!/usr/bin/env bash
# Критерий фазы 2 на «чистом VPS»: Debian 12 с systemd в контейнере.
# Ставит ylsrv одним бинарником (sudo ylsrv init), запускает службу, входит
# случайным ключом, забирает роль Владельца, передаёт её новым ключом и
# проверяет права файлов, журнал и память. Нужны Go и Docker.
#   tools/vps-smoke.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(mktemp -d)"
name="yl-vps-smoke-$$"
image="yeenlink-vps-smoke:debian12"
cleanup() { docker rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$out"; }
trap cleanup EXIT

(cd "$root/server" &&
  CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.version=smoke" -o "$out/ylsrv" ./cmd/ylsrv &&
  CGO_ENABLED=0 go build -trimpath -o "$out/yl-smoke" ./cmd/yl-smoke)
ls -l "$out/ylsrv"

docker build -q -t "$image" - >/dev/null <<'DOCKERFILE'
FROM debian:12
RUN apt-get update && apt-get install -y --no-install-recommends systemd systemd-sysv procps curl ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && systemctl mask getty.target systemd-logind.service
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
DOCKERFILE

docker run -d --name "$name" --privileged --cgroupns=host -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --tmpfs /run --tmpfs /run/lock -v "$out:/opt/smoke:ro" "$image" >/dev/null
for _ in $(seq 60); do
  state="$(docker exec "$name" systemctl is-system-running 2>/dev/null || true)"
  case "$state" in running|degraded) break ;; esac
  sleep 1
done

docker exec -i "$name" bash -euo pipefail <<'INSIDE'
fail() { echo "ПРОВАЛ: $*" >&2; journalctl -u ylsrv --no-pager | tail -30 >&2 || true; exit 1; }
check_mode() { [ "$(stat -c '%U:%G %a' "$1")" = "$2" ] || fail "$1: $(stat -c '%U:%G %a' "$1"), нужно $2"; }

# Как скачанный файл: лежит в домашнем каталоге root.
cp /opt/smoke/ylsrv /root/ylsrv && chmod +x /root/ylsrv
/root/ylsrv init --non-interactive --name "Смоук" --host 127.0.0.1 > /root/init.txt
cat /root/init.txt
grep -q 'ylat_' /root/init.txt && fail "ключ администратора напечатан не в терминал"

[ -x /usr/local/bin/ylsrv ] || fail "бинарник не установлен"
id yeenlink >/dev/null || fail "нет пользователя yeenlink"
check_mode /etc/yeenlink/ylsrv.toml "root:yeenlink 640"
check_mode /var/lib/yeenlink "yeenlink:yeenlink 700"
check_mode /var/lib/yeenlink/server.key "yeenlink:yeenlink 600"
check_mode /var/lib/yeenlink/admin-token "yeenlink:yeenlink 600"
check_mode /var/lib/yeenlink/yeenlink.db "yeenlink:yeenlink 600"

systemctl enable --now ylsrv
for _ in $(seq 50); do curl -sfk https://127.0.0.1/healthz >/dev/null && break; sleep 0.2; done
curl -sfk https://127.0.0.1/healthz >/dev/null || fail "сервер не отвечает"

key="$(grep -A2 'Ключ сервера' /root/init.txt | tail -1 | tr -d ' ')"
/opt/smoke/yl-smoke --url https://127.0.0.1 --token-file /var/lib/yeenlink/admin-token --expect-key "$key" \
  || fail "вход и admin.claim"

# Новый ключ из консоли: файл остаётся службе, роль переходит к другому ключу.
/usr/local/bin/ylsrv admin-token > /root/token.txt
grep -q 'ylat_' /root/token.txt && fail "admin-token напечатал ключ не в терминал"
check_mode /var/lib/yeenlink/admin-token "yeenlink:yeenlink 600"
/opt/smoke/yl-smoke --url https://127.0.0.1 --token-file /var/lib/yeenlink/admin-token --expect-key "$key" \
  || fail "передача роли новым ключом"

journalctl -u ylsrv --no-pager > /root/journal.txt
grep -q 'ylat_' /root/journal.txt && fail "ключ администратора в журнале"
grep -q 'владелец сервера сменился' /root/journal.txt || fail "смены владельца нет в журнале"

systemctl restart ylsrv
for _ in $(seq 50); do curl -sfk https://127.0.0.1/healthz >/dev/null && break; sleep 0.2; done
systemctl is-active --quiet ylsrv || fail "после перезапуска служба не работает"
rss="$(ps -o rss= -C ylsrv | head -1 | tr -d ' ')"
echo "RSS: ${rss} КБ"
[ "$rss" -lt 102400 ] || fail "RSS ${rss} КБ — больше 100 МБ"
echo "vps-smoke: ok"
INSIDE
