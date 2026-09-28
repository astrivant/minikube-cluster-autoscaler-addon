#!/usr/bin/env python3
"""
Combine Go statement coverage across platforms for the coverage badge.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import TypedDict


class CoverageTotals(TypedDict):
    """
    Store statement counts and the displayed percentage consumed by the badge action.

    Attributes:
        num_statements (int): Total application statements represented in the reports.
        covered_statements (int): Statements executed on at least one host platform.
        percent_covered_display (str): Percentage rounded to one decimal place for the badge.
    """

    num_statements: int
    covered_statements: int
    percent_covered_display: str


def summarize(profiles: list[Path]) -> dict[str, CoverageTotals]:
    """
    Combine executed statement blocks across host platforms, excluding generated code.

    Args:
        profiles (list[Path]): Go coverage reports for the same source revision.

    Returns:
        dict[str, CoverageTotals]: Aggregate statement counts and badge percentage.
    """
    blocks: dict[str, tuple[int, bool]] = {}
    for path in profiles:
        lines = path.read_text().splitlines()
        if not lines or lines[0] not in ("mode: set", "mode: count", "mode: atomic"):
            raise ValueError(f"{path}: missing Go coverage mode")
        for line in lines[1:]:
            location, raw_statements, raw_executions = line.split()
            if "/pkg/internal/protos/" in location:
                continue
            statements, executions = int(raw_statements), int(raw_executions)
            previous = blocks.get(location)
            if previous is not None and previous[0] != statements:
                raise ValueError(f"{location}: inconsistent statement counts")
            blocks[location] = (statements, executions > 0 or (previous is not None and previous[1]))
    total = sum(statements for statements, _ in blocks.values())
    covered = sum(statements for statements, hit in blocks.values() if hit)
    if total == 0:
        raise ValueError("No application statements found in coverage profiles")
    return {
        "totals": {
            "num_statements": total,
            "covered_statements": covered,
            "percent_covered_display": f"{100 * covered / total:.1f}",
        }
    }


def main() -> None:
    """
    Write the combined coverage report and print its statement totals.

    Returns:
        None: The JSON report is written to the selected output path.
    """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profiles", nargs="+", type=Path)
    parser.add_argument("--output", type=Path, default=Path("coverage.json"))
    args = parser.parse_args()
    report = summarize(args.profiles)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    totals = report["totals"]
    print(f"Go statement coverage: {totals['percent_covered_display']}% ({totals['covered_statements']}/{totals['num_statements']})")


if __name__ == "__main__":
    main()
