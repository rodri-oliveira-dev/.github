#!/usr/bin/env python3
"""Derive the least-privilege repository scope for the write token."""
import argparse
import json
import re
from pathlib import Path

OWNER = re.compile(r"^[A-Za-z0-9-]{1,39}$")
REPOSITORY = re.compile(r"^([A-Za-z0-9-]{1,39})/([A-Za-z0-9_.-]+)$")


def repository_scope(report, owner):
    if not OWNER.fullmatch(owner):
        raise ValueError("Invalid owner")
    names = set()
    findings = report.get("findings", [])
    if not isinstance(findings, list):
        raise ValueError("Audit report findings must be a list")
    for item in findings:
        if not isinstance(item, dict):
            continue
        full_name = item.get("repository")
        if not isinstance(full_name, str):
            continue
        match = REPOSITORY.fullmatch(full_name)
        if match and match.group(1).lower() == owner.lower():
            names.add(match.group(2))
    return sorted(names)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--github-output", type=Path, required=True)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    names = repository_scope(report, args.owner)
    with args.github_output.open("a", encoding="utf-8") as output:
        output.write(f"count={len(names)}\n")
        output.write("repositories=" + ",".join(names) + "\n")


if __name__ == "__main__":
    main()
