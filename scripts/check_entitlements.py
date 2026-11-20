#!/usr/bin/env python3
"""Проверка entitlements перед сборкой.

Push на iOS не работает без `aps-environment` в подписанном приложении —
профиль может содержать его, но codesign берёт entitlements из файла проекта.
Скрипт падает, если ключ пропал или сломалось окружение Debug/Release.
"""

from __future__ import annotations

import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENTITLEMENTS = ROOT / "Muzea/Resources/Muzea.entitlements"
PROJECT = ROOT / "project.yml"


def main() -> int:
    errors: list[str] = []

    try:
        data = plistlib.loads(ENTITLEMENTS.read_bytes())
    except Exception as error:  # noqa: BLE001 - показываем причину как есть
        print(f"Не удалось прочитать {ENTITLEMENTS}: {error}", file=sys.stderr)
        return 1

    aps = data.get("aps-environment")
    if aps != "$(APS_ENVIRONMENT)":
        errors.append(
            "Muzea.entitlements: aps-environment должен быть "
            f"'$(APS_ENVIRONMENT)', а не {aps!r}"
        )

    domains = data.get("com.apple.developer.associated-domains") or []
    if "applinks:muzea.su" not in domains:
        errors.append("Muzea.entitlements: нет applinks:muzea.su")

    project = PROJECT.read_text(encoding="utf-8")
    if "APS_ENVIRONMENT: development" not in project:
        errors.append("project.yml: не задан APS_ENVIRONMENT для Debug")
    if "APS_ENVIRONMENT: production" not in project:
        errors.append("project.yml: не задан APS_ENVIRONMENT для Release")

    if errors:
        for error in errors:
            print(f"::error::{error}")
        return 1

    print("Entitlements в порядке: push (production/development) и Universal Links на месте")
    return 0


if __name__ == "__main__":
    sys.exit(main())
