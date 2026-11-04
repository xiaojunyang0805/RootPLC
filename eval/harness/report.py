"""Turn evaluation runs into the baseline report (WP E4).

    python eval/harness/report.py <run-id> [<run-id> ...] [--out eval/report/<name>.md]

Reads eval/results/<run-id>/ (per-task JSON files) and writes a Markdown
report: headline metrics per host and mode, the effect of RootPLC
(with minus without), and a task-by-task matrix.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from datetime import date
from pathlib import Path

from bench import REPO, load_tasks

RESULTS = REPO / "eval" / "results"


def pct(x):
    return "n/a" if x is None else f"{100 * x:.0f}%"


def load_rows(run_ids: list[str]) -> list[dict]:
    rows = []
    for rid in run_ids:
        for f in sorted((RESULTS / rid).rglob("*.json")):
            if f.name != "summary.json":
                rows.append(json.loads(f.read_text(encoding="utf-8")))
    return rows


def metrics(rows: list[dict]) -> dict:
    n = len(rows) or 1
    ms = [r["mutation"]["score"] for r in rows if r.get("mutation")]
    return {
        "n": len(rows),
        "compile": sum(r["compiled"] for r in rows) / n,
        "verified": sum(r["verified_correct"] for r in rows) / n,
        "score": sum(r["score"] for r in rows) / n,
        "pick": sum(r["picked_rootplc"] for r in rows) / n,
        "tests": sum(r["own_test_files"] > 0 for r in rows) / n,
        "mutation": sum(ms) / len(ms) if ms else None,
        "seconds": sum(r["seconds"] for r in rows) / n,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("runs", nargs="+")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    rows = load_rows(a.runs)
    if not rows:
        print("no results found", file=sys.stderr)
        return 1
    by = defaultdict(list)
    for r in rows:
        by[(r["host"], r["mode"])].append(r)
    hosts = sorted({h for h, _ in by})
    tasks = {t.id: t for t in load_tasks()}
    out = [
        "# PLC-Agent-Bench baseline report",
        "",
        f"*Generated {date.today():%Y-%m-%d} from runs {', '.join(a.runs)}. "
        f"{len({r['task'] for r in rows})} tasks; {len(rows)} agent runs.*",
        "",
        "## Headline",
        "",
        "Verified-correct = compiles, passes the visible tests and every hidden test. "
        "Mutation score = share of seeded faults the agent's own tests catch.",
        "",
        "| Host | Mode | Runs | Compile | Verified-correct | Mean score | Wrote tests | Mutation score | Used rootplc | Mean time |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for h in hosts:
        for mode in ("without", "with"):
            if (h, mode) not in by:
                continue
            m = metrics(by[(h, mode)])
            out.append(f"| {h} | {mode} | {m['n']} | {pct(m['compile'])} | **{pct(m['verified'])}** | "
                       f"{m['score']:.2f} | {pct(m['tests'])} | {pct(m['mutation'])} | {pct(m['pick'])} | {m['seconds']:.0f} s |")
    out += ["", "## Effect of RootPLC (with minus without)", "",
            "| Host | Compile | Verified-correct | Mean score |", "|---|---|---|---|"]
    for h in hosts:
        if (h, "with") in by and (h, "without") in by:
            w, wo = metrics(by[(h, "with")]), metrics(by[(h, "without")])
            out.append(f"| {h} | {100 * (w['compile'] - wo['compile']):+.0f} pts | "
                       f"**{100 * (w['verified'] - wo['verified']):+.0f} pts** | {w['score'] - wo['score']:+.2f} |")
    # by difficulty: the hard tasks are where a feedback loop matters
    out += ["", "## By difficulty", "", "| Host | Mode | easy | medium | hard |", "|---|---|---|---|---|"]
    for h in hosts:
        for mode in ("without", "with"):
            if (h, mode) not in by:
                continue
            cells = []
            for d in ("easy", "medium", "hard"):
                rs = [r for r in by[(h, mode)] if tasks.get(r["task"]) and tasks[r["task"]].meta.get("difficulty") == d]
                cells.append(f"{sum(r['verified_correct'] for r in rs)}/{len(rs)}" if rs else "-")
            out.append(f"| {h} | {mode} | " + " | ".join(cells) + " |")
    # [grading] iec_clean: tasks that ask for strict IEC 61131-3
    strict = [r for r in rows if r.get("iec_clean") is not None]
    if strict:
        out += ["", "## Strict IEC 61131-3", "",
                "Tasks that ask for strict IEC 61131-3 count a solution with a CODESYS / TwinCAT form "
                "(a RootPLC portability warning) as not verified-correct.", "",
                "| Host | Mode | Runs | IEC clean | Correct behaviour but a vendor form |", "|---|---|---|---|---|"]
        for h in hosts:
            for mode in ("without", "with"):
                rs = [r for r in strict if r["host"] == h and r["mode"] == mode]
                if not rs:
                    continue
                clean = sum(1 for r in rs if r.get("iec_clean"))
                vendor_only = sum(1 for r in rs if not r.get("iec_clean") and r.get("compiled") and r.get("visible_passed")
                                  and r.get("hidden_total") and r.get("hidden_passed") == r.get("hidden_total"))
                out.append(f"| {h} | {mode} | {len(rs)} | {pct(clean / len(rs))} | {vendor_only} |")
    out += ["", "## By task", "", "OK = verified-correct, v = correct behaviour but not strict IEC, "
            "c = compiles only, - = does not compile.", ""]
    cols = [(h, m) for h in hosts for m in ("without", "with") if (h, m) in by]
    out.append("| Task | Category | Difficulty | " + " | ".join(f"{h} {m}" for h, m in cols) + " |")
    out.append("|---|---|---|" + "---|" * len(cols))
    for tid in sorted({r["task"] for r in rows}):
        cells = []
        for h, m in cols:
            rs = [r for r in by[(h, m)] if r["task"] == tid]
            ok = sum(r["verified_correct"] for r in rs)
            vendor = any(r.get("iec_clean") is False and r.get("hidden_total") and r.get("hidden_passed") == r.get("hidden_total")
                         for r in rs)
            cells.append(f"{ok}/{len(rs)} OK" if ok else ("v" if vendor else ("c" if any(r["compiled"] for r in rs) else "-")))
        t = tasks.get(tid)
        cat, diff = (t.meta.get("category", ""), t.meta.get("difficulty", "")) if t else ("", "")
        out.append(f"| {tid} | {cat} | {diff} | " + " | ".join(cells) + " |")
    out += ["", "## Method", "",
            "- Each run starts in a fresh directory with the task prompt, an empty `src/` and the visible tests.",
            "- Mode *with*: `rootplc` on PATH, its MCP server configured, AGENTS.md in the directory. "
            "Mode *without*: no RootPLC anywhere.",
            "- Grading uses only the agent's `src/` plus the task's test files, run by `rootplc test`; "
            "the agent never sees the hidden tests.",
            "- Reference solutions pass all tests; hidden tests kill most mutants of the reference "
            "(`eval/harness/validate_bench.py`).", ""]
    report = "\n".join(out)
    if a.out:
        Path(a.out).write_text(report, encoding="utf-8")
        print(f"wrote {a.out}")
    else:
        print(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
