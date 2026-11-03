"""Differential test against IronPLC (WP X1): run every conformance case
through `ironplcc check` and compare its verdict (accept / reject) with the
case's expectation.

    IRONPLCC=/path/to/ironplcc python eval/oracle/ironplc_diff.py [--out report.md]

IronPLC is a separate MIT-licensed project; it runs out of process and none
of its code is used. Codes are not compared (each tool has its own), only
whether a program is accepted. Cases that use RootPLC extensions IronPLC does
not implement (TEST blocks, assertions, ADVANCE) are reported as "n/a".
Every disagreement is triaged by hand: our bug, their bug, or a policy
difference (for example RootPLC rejecting implicit narrowing).
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CASES = REPO / "conformance" / "cases"
EXTENSIONS = re.compile(r"^\s*TEST\b|ASSERT_(TRUE|FALSE|EQ|NE)|ADVANCE\s*\(", re.M | re.I)


def expectation(text: str) -> str:
    m = re.search(r"expect:\s*(ok|error|warning)", text)
    return {"ok": "accept", "warning": "accept", "error": "reject"}.get(m.group(1) if m else "", "?")


def ironplc_verdict(exe: str, path: Path) -> tuple[str, str]:
    try:
        p = subprocess.run([exe, "check", str(path)], capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return "timeout", ""
    out = (p.stdout + p.stderr).strip().replace("\n", " ")[:200]
    return ("accept" if p.returncode == 0 else "reject"), out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    exe = os.environ.get("IRONPLCC") or shutil.which("ironplcc")
    if not exe:
        print("ironplcc not found: build IronPLC and set IRONPLCC", file=sys.stderr)
        return 2
    rows, counts = [], {"agree": 0, "disagree": 0, "n/a": 0}
    for case in sorted(CASES.rglob("*.st")):
        text = case.read_text(encoding="utf-8")
        name = case.relative_to(CASES).as_posix()
        if EXTENSIONS.search(text):
            counts["n/a"] += 1
            rows.append((name, expectation(text), "n/a", "uses RootPLC test extensions", ""))
            continue
        ours = expectation(text)
        theirs, out = ironplc_verdict(exe, case)
        status = "agree" if ours == theirs else "disagree"
        counts[status] += 1
        rows.append((name, ours, theirs, status, out))
    lines = [
        "# IronPLC differential report",
        "",
        f"Cases: {sum(counts.values())} · agree {counts['agree']} · disagree {counts['disagree']} · n/a {counts['n/a']}",
        "",
        "| Case | RootPLC | IronPLC | Status | Triage | IronPLC output |",
        "|---|---|---|---|---|---|",
    ]
    for name, ours, theirs, status, out in rows:
        if status == "n/a":
            continue
        triage = "" if status == "agree" else "TODO: ours / theirs / policy"
        lines.append(f"| {name} | {ours} | {theirs} | {status} | {triage} | {out.replace('|', '/')} |")
    report = "\n".join(lines) + "\n"
    if a.out:
        Path(a.out).write_text(report, encoding="utf-8")
    print(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
