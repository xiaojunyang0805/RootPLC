"""Differential test against IronPLC (WP X1): run every conformance case
through `ironplcc check` and compare its verdict (accept / reject) with the
case's expectation.

    IRONPLCC=/path/to/ironplcc python eval/oracle/ironplc_diff.py [--out report.md]
    IRONPLCC=wsl:/mnt/c/.../ironplcc python eval/oracle/ironplc_diff.py   # Linux build in WSL

IronPLC is a separate MIT-licensed project; it runs out of process and none
of its code or library sources is used (clean-room, AGENTS.md). Codes are
not compared (each tool has its own), only whether a program is accepted.
Each case is checked twice: in IronPLC's strict IEC 61131-3 ed.3 mode and in
its TwinCAT mode. A case RootPLC accepts without a warning ("ok") should be
accepted by strict ed.3; one RootPLC accepts with a portability warning
("warning") is a vendor form and is compared with the TwinCAT mode; a case
RootPLC rejects should be rejected by both. Cases that use RootPLC
extensions IronPLC does not implement (TEST blocks, assertions, ADVANCE)
are "n/a". Every disagreement is triaged by hand: our bug, their bug, or a
policy difference (for example RootPLC rejecting implicit narrowing).
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
    return m.group(1) if m else "?"


def command() -> tuple[list[str], bool] | None:
    """The ironplcc command line prefix, and whether paths go to WSL."""
    exe = os.environ.get("IRONPLCC") or shutil.which("ironplcc")
    if not exe:
        return None
    if exe.startswith("wsl:"):
        return ["wsl", "-e", exe[4:]], True
    return [exe], False


def wsl_path(p: Path) -> str:
    s = str(p.resolve())
    m = re.match(r"([A-Za-z]):[\\/](.*)", s)
    return f"/mnt/{m.group(1).lower()}/{m.group(2).replace(chr(92), '/')}" if m else s


def ironplc_verdict(cmd: tuple[list[str], bool], path: Path, dialect: str) -> tuple[str, str]:
    prefix, wsl = cmd
    target = wsl_path(path) if wsl else str(path)
    try:
        p = subprocess.run([*prefix, "check", "--dialect", dialect, target],
                           capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60)
    except subprocess.TimeoutExpired:
        return "timeout", ""
    out = re.sub(r"\s+", " ", p.stdout + p.stderr).strip()[:160]
    return ("accept" if p.returncode == 0 else "reject"), out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    cmd = command()
    if not cmd:
        print("ironplcc not found: set IRONPLCC (a path, or wsl:/path for a Linux build)", file=sys.stderr)
        return 2
    rows, counts = [], {"agree": 0, "disagree": 0, "n/a": 0}
    for case in sorted(CASES.rglob("*.st")):
        text = case.read_text(encoding="utf-8")
        name = case.relative_to(CASES).as_posix()
        ours = expectation(text)
        if EXTENSIONS.search(text) or ours == "?":
            counts["n/a"] += 1
            continue
        strict, out_s = ironplc_verdict(cmd, case, "iec61131-3-ed3")
        vendor, out_v = ironplc_verdict(cmd, case, "twincat")
        if ours == "ok":
            ok = strict == "accept"
        elif ours == "warning":
            ok = vendor == "accept"
        else:
            ok = strict == "reject" and vendor == "reject"
        status = "agree" if ok else "disagree"
        counts[status] += 1
        rows.append((name, ours, strict, vendor, status, out_s if strict == "reject" else out_v))
    lines = [
        "# IronPLC differential report",
        "",
        f"IronPLC {version(cmd)} · cases compared {counts['agree'] + counts['disagree']} · "
        f"agree {counts['agree']} · disagree {counts['disagree']} · n/a {counts['n/a']} (RootPLC test extensions)",
        "",
        "| Case | RootPLC | IronPLC ed.3 | IronPLC TwinCAT | Status | Triage | IronPLC output |",
        "|---|---|---|---|---|---|---|",
    ]
    for name, ours, strict, vendor, status, out in sorted(rows, key=lambda r: (r[4] != "disagree", r[0])):
        triage = "" if status == "agree" else "TODO: ours / theirs / policy"
        lines.append(f"| {name} | {ours} | {strict} | {vendor} | {status} | {triage} | {out.replace('|', '/')} |")
    report = "\n".join(lines) + "\n"
    if a.out:
        Path(a.out).write_text(report, encoding="utf-8")
    print("\n".join(lines[:3]))
    return 0


def version(cmd: tuple[list[str], bool]) -> str:
    p = subprocess.run([*cmd[0], "version"], capture_output=True, text=True)
    return p.stdout.strip().split()[-1] if p.returncode == 0 and p.stdout.strip() else "?"


if __name__ == "__main__":
    sys.exit(main())
