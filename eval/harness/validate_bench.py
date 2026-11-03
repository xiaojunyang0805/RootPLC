"""Validate the bench: every reference solution must pass its visible and
hidden tests, and the hidden tests must kill most mutants of the reference.

    python eval/harness/validate_bench.py [--min-score 0.7] [task ...]
"""
from __future__ import annotations

import argparse
import sys

from bench import grade, load_tasks
from mutate import mutation_score


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("tasks", nargs="*")
    ap.add_argument("--min-score", type=float, default=0.7)
    ap.add_argument("--survivors", action="store_true", help="list surviving mutants")
    a = ap.parse_args()
    bad = 0
    print(f"{'task':28} {'ref':>4} {'mutants':>8} {'killed':>7} {'score':>6}")
    for t in load_tasks(a.tasks or None):
        g = grade(t, t.dir / "reference")
        m = mutation_score(sorted((t.dir / "reference").glob("*.st")), [t.dir / "hidden_tests.st"])
        eq = len(t.meta.get("equivalent_mutants", []))
        m.viable -= min(eq, len(m.survivors))  # declared equivalent mutants are not counted
        ok = g.verified_correct and m.score >= a.min_score
        bad += not ok
        print(f"{t.id:28} {'ok' if g.verified_correct else 'FAIL':>4} {m.viable:>8} {m.killed:>7} {m.score:>6.0%}"
              + ("" if ok else "  <--"))
        if a.survivors or not ok:
            for s in m.survivors:
                print(f"    survives: {s}")
    print(f"\n{bad} task(s) below the bar")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
