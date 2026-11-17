#!/usr/bin/env python3
"""Проверка локализации без Xcode.

1. Каждый ключ из `L10n.swift` обязан быть в обеих таблицах (`ru`, `en`).
2. Наборы ключей в таблицах должны совпадать.
3. Форматтеры `%d`/`%@` должны встречаться в переводах в том же количестве.
4. В переведённых экранах (`Features/Chat`) не должно оставаться кириллицы
   в строковых литералах.

Запуск: `python3 scripts/check_localization.py`
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
L10N_SWIFT = ROOT / "Muzea/Core/Localization/L10n.swift"
TABLES = {
    "ru": ROOT / "Muzea/Resources/ru.lproj/Localizable.strings",
    "en": ROOT / "Muzea/Resources/en.lproj/Localizable.strings",
}
CHECKED_DIRS = [
    ROOT / "Muzea/Features",
    ROOT / "Muzea/App",
    ROOT / "Muzea/Core",
    ROOT / "Muzea/Domain",
]

KEY_CALL = re.compile(r'(?:t|format)\("([^"]+)"')
TABLE_LINE = re.compile(r'^"([^"]+)"\s*=\s*"(.*)";\s*$')
CYRILLIC = re.compile(r'"[^"\n]*[А-Яа-яЁё][^"\n]*"')
PLACEHOLDER = re.compile(r'%(?:\d+\$)?[@dfsu]')


DECLARED = re.compile(r'static (?:var|func) (\w+)')
USAGE = re.compile(r'L10n\.(\w+)')


def used_keys() -> set[str]:
    return set(KEY_CALL.findall(L10N_SWIFT.read_text()))


def getters() -> set[str]:
    return set(DECLARED.findall(L10N_SWIFT.read_text()))


def getter_usages() -> set[str]:
    used: set[str] = set()
    for base in (ROOT / "Muzea", ROOT / "MuzeaTests"):
        for path in base.rglob("*.swift"):
            if path == L10N_SWIFT:
                continue
            used |= set(USAGE.findall(path.read_text()))
    return used


def table(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("/*") or line.startswith("//"):
            continue
        match = TABLE_LINE.match(line)
        if match:
            entries[match.group(1)] = match.group(2)
    return entries


def main() -> int:
    problems: list[str] = []
    used = used_keys()
    ru = table(TABLES["ru"])
    en = table(TABLES["en"])

    for lang, entries in (("ru", ru), ("en", en)):
        missing = sorted(used - entries.keys())
        if missing:
            problems.append(f"{lang}: нет ключей {missing}")
        extra = sorted(entries.keys() - used)
        if extra:
            problems.append(f"{lang}: не используются {extra}")

    for key in sorted(used & ru.keys() & en.keys()):
        ru_placeholders = sorted(PLACEHOLDER.findall(ru[key]))
        en_placeholders = sorted(PLACEHOLDER.findall(en[key]))
        if len(ru_placeholders) != len(en_placeholders):
            problems.append(
                f"{key}: плейсхолдеры не совпадают ru={ru_placeholders} en={en_placeholders}"
            )

    declared = getters() - {"t", "format"}
    used_getters = getter_usages()
    unknown = sorted(used_getters - declared)
    if unknown:
        problems.append(f"L10n: нет геттеров {unknown}")
    dead = sorted(declared - used_getters)
    if dead:
        problems.append(f"L10n: не используются геттеры {dead}")

    leaked: list[str] = []
    for directory in CHECKED_DIRS:
        for path in sorted(directory.rglob("*.swift")):
            previous = ""
            for number, line in enumerate(path.read_text().splitlines(), 1):
                stripped = line.strip()
                skipped = (
                    stripped.startswith("//")
                    or "print(" in line
                    or "l10n:ignore" in previous
                )
                if not skipped and CYRILLIC.search(line):
                    leaked.append(f"{path.relative_to(ROOT)}:{number}: {stripped}")
                previous = stripped

    if leaked:
        problems.append("кириллица в литералах:\n  " + "\n  ".join(leaked))

    if problems:
        print("Проверка локализации не пройдена:\n")
        for problem in problems:
            print(f"- {problem}")
        return 1

    print(f"Локализация в порядке: {len(used)} ключей × {len(TABLES)} языка")
    return 0


if __name__ == "__main__":
    sys.exit(main())
