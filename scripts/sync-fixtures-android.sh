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
TARGET="$ANDROID_REPO/app/src/test/resources/fixtures/chat"

mkdir -p "$TARGET"
cp "$ROOT"/docs/fixtures/chat/*.json "$TARGET"/
cp "$ROOT/docs/fixtures/README.md" "$TARGET/README.md"
echo "fixtures synced to $TARGET"
