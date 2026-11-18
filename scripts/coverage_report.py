#!/usr/bin/env python3
"""Отчёт и гейт покрытия iOS-тестов по JSON от `xccov view --report --json`.

Пример:

    xcrun xccov view --report --json build/TestResults.xcresult > build/coverage.json
    python3 scripts/coverage_report.py build/coverage.json --min 70

Гейт считается по основному таргету приложения (Muzea.app), а не по тестам
и расширению: иначе цифра раздувается за счёт самих тестов.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def percent(value: float) -> str:
    return f"{value * 100:.1f}%"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--min", type=float, default=0.0, help="минимальный % для Muzea.app")
    parser.add_argument("--top", type=int, default=25)
    args = parser.parse_args()

    report = json.loads(args.report.read_text())
    targets = report.get("targets", [])
    app = next(
        (t for t in targets if t.get("name", "").startswith("Muzea.app")),
        None,
    )
    if app is None:
        print("Muzea.app не найден в отчёте покрытия", file=sys.stderr)
        return 2

    print(f"Покрытие {app['name']}: {percent(app['lineCoverage'])}")
    print(f"  строк: {app['coveredLines']} / {app['executableLines']}")
    for target in targets:
        if target is app:
            continue
        print(f"{target['name']}: {percent(target['lineCoverage'])}")

    files = [f for f in app.get("files", []) if f.get("executableLines", 0) > 0]
    gaps = sorted(
        files,
        key=lambda f: f["executableLines"] * (1 - f["lineCoverage"]),
        reverse=True,
    )
    print(f"\nТоп-{args.top} файлов, где теряется покрытие:")
    for f in gaps[: args.top]:
        uncovered = f["executableLines"] - f["coveredLines"]
        print(f"  {percent(f['lineCoverage']):>6}  -{uncovered:<5} {f['path']}")

    coverage = app["lineCoverage"] * 100
    if args.min and coverage < args.min:
        print(f"\nГейт не пройден: {coverage:.1f}% < {args.min:.1f}%", file=sys.stderr)
        return 1
    if args.min:
        print(f"\nГейт пройден: {coverage:.1f}% >= {args.min:.1f}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
