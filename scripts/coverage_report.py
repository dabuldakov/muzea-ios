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


VIEW_SUFFIXES = (
    "View.swift",
    "Views.swift",
    "Sheet.swift",
    "Row.swift",
    "Bar.swift",
    "Button.swift",
    "Cell.swift",
    "Editor.swift",
    "Chip.swift",
    "MuzeaApp.swift",
    "RouteDestinationView.swift",
)


def percent(value: float) -> str:
    return f"{value * 100:.1f}%"


def is_view(path: str) -> bool:
    return path.rsplit("/", 1)[-1].endswith(VIEW_SUFFIXES)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--min", type=float, default=0.0, help="минимальное покрытие в процентах для Muzea.app")
    parser.add_argument(
        "--min-logic",
        type=float,
        default=0.0,
        help="минимальное покрытие логики: Core/Domain/ViewModel без SwiftUI View",
    )
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

    logic_files = [f for f in app.get("files", []) if not is_view(f["path"])]
    logic_lines = sum(f["executableLines"] for f in logic_files)
    logic_covered = sum(f["coveredLines"] for f in logic_files)
    logic_coverage = logic_covered / logic_lines if logic_lines else 0
    print(
        f"Логика (Core/Domain/ViewModel без SwiftUI View): "
        f"{percent(logic_coverage)} ({logic_covered}/{logic_lines})"
    )
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

    failed = False
    coverage = app["lineCoverage"] * 100
    if args.min and coverage < args.min:
        print(f"\nГейт общего покрытия не пройден: {coverage:.1f}% < {args.min:.1f}%", file=sys.stderr)
        failed = True
    if args.min_logic and logic_coverage * 100 < args.min_logic:
        print(
            f"\nГейт логики не пройден: {logic_coverage * 100:.1f}% < {args.min_logic:.1f}%",
            file=sys.stderr,
        )
        failed = True
    if not failed and args.min_logic:
        print(f"\nГейт логики пройден: {logic_coverage * 100:.1f}% >= {args.min_logic:.1f}%")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
