"""X1 on real code: check each corpus project folder with RootPLC and with
IronPLC (TwinCAT mode) and compare file by file.

    IRONPLCC=wsl:/path/to/ironplcc ROOTPLC_CORPUS_CACHE=... python eval/oracle/ironplc_corpus.py [--out report.md]

A file is "clean" for a tool when the tool reports no error in it. The
interesting cell is RootPLC clean / IronPLC error: either RootPLC accepts
something it should not (a false acceptance the corpus alone cannot show)
or IronPLC lacks a construct. Holdout projects are counted but their files
are never listed (corpus/manifest.toml). Only the core categories
(application, library, sample) are checked. IronPLC runs out of process;
none of its code or library sources is used.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "corpus"))
import corpus  # noqa: E402  (manifest, cache and library helpers)
from ironplc_diff import command, wsl_path  # noqa: E402

TOLERANCES = ["--allow-missing-semicolon", "--allow-c-style-comments", "--allow-pragmas"]


def ironplc_errors(cmd, folder: Path) -> tuple[set[str], str]:
    prefix, wsl = cmd
    target = wsl_path(folder) if wsl else str(folder)
    try:
        p = subprocess.run([*prefix, "check", "--dialect", "twincat", *TOLERANCES, target],
                           capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
    except subprocess.TimeoutExpired:
        return set(), "timeout"
    text = re.sub(r"\x1b\[[0-9;]*m", "", p.stdout + p.stderr)
    files = set()
    for m in re.finditer(r"┌─\s+(\S+?\.st):\d+:\d+", text):
        f = m.group(1)
        if wsl and f.startswith("/mnt/"):
            f = f"{f[5].upper()}:/{f[7:]}"
        files.add(str(Path(f).resolve()).lower())
    # an error IronPLC could not place in a file counts for the whole folder
    first = re.search(r"error\[(P\d+)\]: ([^\n]*)", text)
    return files, (f"{first.group(1)} {first.group(2)[:80]}" if first else "")


def rootplc_errors(exe: str, folder: Path, libs: list[str]) -> set[str]:
    extra = ["--library", ",".join(libs)] if libs else []
    r = subprocess.run([exe, "check", str(folder), *extra, "--json"], capture_output=True, text=True, encoding="utf-8")
    rep = json.loads(r.stdout) if r.stdout.strip().startswith("{") else {}
    return {str(Path(d["file"]).resolve()).lower() for d in rep.get("diagnostics", []) if d["severity"] == "error"}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    cmd = command()
    if not cmd:
        print("ironplcc not found: set IRONPLCC", file=sys.stderr)
        return 2
    exe = corpus.rootplc()
    shipped = corpus.shipped_libraries(exe)
    cells, per_project, examples = Counter(), [], []
    for p in corpus.projects():
        if p.get("category") not in corpus.CORE or p["format"] in ("binary", "none"):
            continue
        d = corpus.CACHE / p["name"] / "extracted"
        if not d.exists():
            continue
        subdirs = sorted(x for x in d.iterdir() if x.is_dir())
        folders = subdirs if subdirs else [d]
        if subdirs and list(d.glob("*.st")):
            folders = subdirs + [d]
        pc = Counter()
        for folder in folders:
            files = sorted(folder.glob("*.st")) if folder == d and subdirs else sorted(folder.rglob("*.st"))
            if not files:
                continue
            libs = corpus.libraries_for(folder, p["format"], shipped)
            ours = rootplc_errors(exe, folder, libs)
            theirs, first = ironplc_errors(cmd, folder)
            whole_folder = bool(first) and not theirs   # failed before naming a file
            for f in files:
                key = str(f.resolve()).lower()
                r_ok = key not in ours
                i_ok = not whole_folder and key not in theirs
                cell = ("rootplc clean" if r_ok else "rootplc error") + " / " + ("ironplc clean" if i_ok else "ironplc error")
                pc[cell] += 1
                if r_ok and not i_ok and not p.get("holdout") and len(examples) < 400:
                    examples.append((p["name"], f.name, first))
        cells.update(pc)
        per_project.append((p["name"], bool(p.get("holdout")), pc))
        print(f"{p['name'][:44]:44} " + "  ".join(f"{k.split()[1][0]}{k.split()[-1][0]}={v}" for k, v in sorted(pc.items())), flush=True)
    total = sum(cells.values()) or 1
    lines = ["# X1 on the corpus: RootPLC and IronPLC (TwinCAT mode), file by file", "",
             f"Core-set files: {total}. IronPLC run with --dialect twincat and {' '.join(TOLERANCES)}.", "",
             "| RootPLC / IronPLC | Files |", "|---|---|"]
    for k, v in cells.most_common():
        lines.append(f"| {k} | {v} ({100 * v / total:.1f}%) |")
    lines += ["", "## RootPLC clean, IronPLC error (non-holdout, first IronPLC error of the folder)", "",
              "| Project | File | IronPLC |", "|---|---|---|"]
    lines += [f"| {a} | {b} | {c.replace('|', '/')} |" for a, b, c in examples]
    report = "\n".join(lines) + "\n"
    if a.out:
        Path(a.out).write_text(report, encoding="utf-8")
    print("\n".join(lines[:12]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
