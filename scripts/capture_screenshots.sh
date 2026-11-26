#!/usr/bin/env bash
# Снимает экраны приложения в симуляторе для App Store Connect.
#
# Использование:
#   scripts/capture_screenshots.sh <Muzea.app> <UDID> <access> <refresh> <ru|en> <output-dir>
#
# Скрипт не содержит секретов: токены передаёт CI. Демо-аккаунт и данные
# описаны в docs/APP_STORE.md.
set -euo pipefail

APP="${1:?path to Muzea.app}"
UDID="${2:?simulator UDID}"
ACCESS="${3:?access token}"
REFRESH="${4:?refresh token}"
LOCALE="${5:?locale}"
OUT="${6:?output directory}"
BUNDLE="com.cyber.muzea"
CHAT_UUID="c0000000-0000-4000-8000-000000000002"
NEWS_ID="20"

mkdir -p "$OUT"

# В macOS нет GNU timeout, а зависший simctl не должен блокировать job.
run_timeout() {
  local seconds="$1"
  shift
  perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"
}

echo "==> install app"
run_timeout 120 xcrun simctl install "$UDID" "$APP"
echo "==> status bar"
run_timeout 30 xcrun simctl status_bar "$UDID" override \
  --time "9:41" \
  --dataNetwork wifi \
  --wifiMode active \
  --wifiBars 3 \
  --cellularMode active \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100
run_timeout 30 xcrun simctl ui "$UDID" appearance light

launch() {
  local tab="$1"
  local extra_name="${2:-}"
  local extra_value="${3:-}"
  echo "==> launch tab $tab ($LOCALE)${extra_name:+ $extra_name}"
  run_timeout 30 xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  local -a variables=(
    "SIMCTL_CHILD_MUZEA_SCREENSHOT_ACCESS=$ACCESS"
    "SIMCTL_CHILD_MUZEA_SCREENSHOT_REFRESH=$REFRESH"
    "SIMCTL_CHILD_MUZEA_SCREENSHOT_TAB=$tab"
  )
  if [ -n "$extra_name" ]; then
    variables+=("SIMCTL_CHILD_$extra_name=$extra_value")
  fi
  env "${variables[@]}" run_timeout 60 xcrun simctl launch "$UDID" "$BUNDLE" \
    -AppleLanguages "($LOCALE)" \
    -AppleLocale "$LOCALE" >/dev/null
}

shot() {
  local name="$1"
  echo "==> screenshot $name"
  run_timeout 45 xcrun simctl io "$UDID" screenshot "$OUT/$LOCALE-$name.png" >/dev/null
  run_timeout 30 sips -s format jpeg -s formatOptions 100 \
    "$OUT/$LOCALE-$name.png" --out "$OUT/$LOCALE-$name.jpg" >/dev/null
  rm -f "$OUT/$LOCALE-$name.png"
}

# Новости: список и карточка.
launch 0
sleep 9
shot 01-news

launch 0 MUZEA_SCREENSHOT_NEWS "$NEWS_ID"
sleep 9
shot 02-news-detail

# Чаты: список и переписка.
launch 1
sleep 9
shot 03-chats

launch 1 MUZEA_SCREENSHOT_CHAT "$CHAT_UUID"
sleep 9
shot 04-chat

# Видео и профиль.
launch 3
sleep 9
shot 05-video

launch 4
sleep 7
shot 06-profile

echo "Screenshots:"
for file in "$OUT"/*.jpg; do
  size=$(sips -g pixelWidth -g pixelHeight "$file" | awk '/pixel/{print $2}' | paste -sd x -)
  echo "  $(basename "$file") $size"
done
