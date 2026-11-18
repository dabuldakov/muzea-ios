#!/usr/bin/env python3
"""Проверки релизной конфигурации iOS без Xcode.

- Info.plist: обязательные usage-description, нет ATS-послаблений,
  нет дублирующихся ключей;
- PrivacyInfo.xcprivacy: манифест приватности и required-reason API;
- entitlements: Universal Links;
- InfoPlist.strings: локализации разрешений;
- AASA: корректный JSON и appID;
- в git не попали секреты.

Запуск: `python3 scripts/check_release.py`
"""

from __future__ import annotations

import json
import plistlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INFO = ROOT / "Muzea/Resources/Info.plist"
PRIVACY = ROOT / "Muzea/Resources/PrivacyInfo.xcprivacy"
ENTITLEMENTS = ROOT / "Muzea/Resources/Muzea.entitlements"
AASA = ROOT / "docs/aasa/apple-app-site-association"

REQUIRED_USAGE = [
    "NSCameraUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSPhotoLibraryUsageDescription",
    "NSPhotoLibraryAddUsageDescription",
]
LOCALIZED_USAGE = {
    "ru": ROOT / "Muzea/Resources/ru.lproj/InfoPlist.strings",
    "en": ROOT / "Muzea/Resources/en.lproj/InfoPlist.strings",
}


def main() -> int:
    problems: list[str] = []

    info = plistlib.loads(INFO.read_bytes())
    for key in REQUIRED_USAGE:
        value = info.get(key)
        if not isinstance(value, str) or not value.strip():
            problems.append(f"Info.plist: нет {key}")

    if "NSAppTransportSecurity" in info:
        ats = info["NSAppTransportSecurity"]
        if ats.get("NSAllowsArbitraryLoads"):
            problems.append("Info.plist: NSAllowsArbitraryLoads запрещён")
        if ats.get("NSExceptionDomains"):
            problems.append("Info.plist: ATS-исключения доменов запрещены")

    raw_info = INFO.read_text()
    for key in ("UIBackgroundModes", "CFBundleURLTypes", "NSPhotoLibraryUsageDescription"):
        if raw_info.count(f"<key>{key}</key>") > 1:
            problems.append(f"Info.plist: дублируется {key}")

    if not PRIVACY.exists():
        problems.append("нет PrivacyInfo.xcprivacy")
    else:
        privacy = plistlib.loads(PRIVACY.read_bytes())
        if privacy.get("NSPrivacyTracking") is not False:
            problems.append("PrivacyInfo: NSPrivacyTracking должен быть false")
        if not privacy.get("NSPrivacyCollectedDataTypes"):
            problems.append("PrivacyInfo: не описаны собираемые данные")
        api_types = {
            item.get("NSPrivacyAccessedAPIType")
            for item in privacy.get("NSPrivacyAccessedAPITypes", [])
            if isinstance(item, dict)
        }
        if "NSPrivacyAccessedAPICategoryUserDefaults" not in api_types:
            problems.append("PrivacyInfo: нет required-reason для UserDefaults")

    entitlements = plistlib.loads(ENTITLEMENTS.read_bytes())
    domains = entitlements.get("com.apple.developer.associated-domains", [])
    if "applinks:muzea.su" not in domains:
        problems.append("Entitlements: нет applinks:muzea.su")

    for language, path in LOCALIZED_USAGE.items():
        if not path.exists():
            problems.append(f"нет InfoPlist.strings для {language}")
            continue
        text = path.read_text()
        for key in REQUIRED_USAGE:
            if f'"{key}"' not in text:
                problems.append(f"InfoPlist.strings ({language}): нет {key}")

    try:
        aasa = json.loads(AASA.read_text())
        details = aasa.get("applinks", {}).get("details", [])
        app_ids = {item.get("appID") for item in details if isinstance(item, dict)}
        if "5HGZ927RW5.com.cyber.muzea" not in app_ids:
            problems.append("AASA: нет appID 5HGZ927RW5.com.cyber.muzea")
        for item in details:
            for component in item.get("components", []):
                path = component.get("/")
                if path not in ("/chat/*", "/news/*", "/share"):
                    problems.append(f"AASA: неожиданный path {path}")
    except (OSError, json.JSONDecodeError) as error:
        problems.append(f"AASA: {error}")

    tracked = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    ).stdout.splitlines()
    forbidden = re.compile(
        r"(^|/)(GoogleService-Info\.plist|AuthKey_[^/]*\.p8|[^/]*\.p12|[^/]*\.mobileprovision|\.env)$"
    )
    leaked = [path for path in tracked if forbidden.search(path)]
    if leaked:
        problems.append(f"в git попали секреты: {leaked}")

    if problems:
        print("Проверка релизной конфигурации не пройдена:\n")
        for problem in problems:
            print(f"- {problem}")
        return 1

    print("Релизная конфигурация в порядке: Info.plist, PrivacyInfo, entitlements, AASA")
    return 0


if __name__ == "__main__":
    sys.exit(main())
