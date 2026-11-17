#!/bin/bash
# Xcode Cloud: подготовка секретов и генерация проекта перед сборкой.
# `project.yml` — источник истины; проект перегенерируем здесь, чтобы новые
# файлы и локализации не зависели от того, обновили ли закоммиченный .xcodeproj.
set -euo pipefail

echo "Xcode Cloud post-clone"

if [[ -n "${GOOGLE_SERVICE_INFO_PLIST:-}" ]]; then
  echo "Writing GoogleService-Info.plist"
  printf '%s' "$GOOGLE_SERVICE_INFO_PLIST" | base64 --decode > Muzea/Resources/GoogleService-Info.plist
fi

if [[ -n "${KLIPY_APP_KEY:-}" ]]; then
  echo "Injecting KLIPY_APP_KEY"
  /usr/libexec/PlistBuddy -c "Set :KLIPY_APP_KEY ${KLIPY_APP_KEY}" Muzea/Resources/Info.plist
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen"
  brew install xcodegen >/dev/null
fi

# Генерация после записи plist: XcodeGen сканирует файлы в момент запуска.
echo "Generating project"
xcodegen generate
