#!/usr/bin/env bash
# Копирует общие фикстуры в Android-репозиторий, чтобы contract-тесты
# использовали тот же JSON. Запускать после изменения docs/fixtures/chat.
set -euo pipefail

ANDROID_REPO="${1:-${ANDROID_REPO:-}}"
if [[ -z "$ANDROID_REPO" ]]; then
  echo "usage: $0 /path/to/android/muzea" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_CHAT="$ANDROID_REPO/app/src/test/resources/fixtures/chat"
TARGET_MAKEUP="$ANDROID_REPO/app/src/test/resources/fixtures/makeup"

mkdir -p "$TARGET_CHAT" "$TARGET_MAKEUP"
cp "$ROOT"/docs/fixtures/chat/*.json "$TARGET_CHAT"/
cp "$ROOT"/docs/fixtures/makeup/*.json "$TARGET_MAKEUP"/
cp "$ROOT/docs/fixtures/README.md" "$TARGET_CHAT/README.md"
echo "fixtures synced to $ANDROID_REPO/app/src/test/resources/fixtures"
