#!/usr/bin/env bash
# Публикует диагностику (хвосты логов + STATUS) в ветку ci-out. Вызов: publish.sh "<статус>" <sha> <repo> <token>
set -u
STATUS="$1"; SHA="$2"; REPO="$3"; TOKEN="$4"
for f in analyze test apk web; do tail -n 400 ci_out/$f.txt > ci_out/$f.tail.txt 2>/dev/null || true; done
echo "$STATUS sha=$SHA" > ci_out/STATUS.txt
rm -rf /tmp/ciout && mkdir /tmp/ciout && cp -r ci_out/. /tmp/ciout/
cd /tmp/ciout && git init -q -b ci-out && git config user.name ci && git config user.email ci@users.noreply.github.com \
  && git add -A && git commit -qm "ci $SHA" && git push -qf "https://x-access-token:${TOKEN}@github.com/${REPO}" ci-out
