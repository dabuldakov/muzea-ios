#!/bin/bash
# Xcode Cloud: подготовка секретов перед сборкой.
# XcodeGen-проект закоммичен; при изменении project.yml его нужно
# перегенерировать и закоммитить.
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
