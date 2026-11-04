"""PLC-Agent-Bench: load tasks and grade a solution with `rootplc`.

Standard library only. Grading never trusts the agent: it copies the agent's
`src/*.st`, adds the task's test files, and runs `rootplc` in a fresh
directory.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import tempfile
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
TASKS = REPO / "bench" / "tasks"


def rootplc_binary() -> str:
    """The rootplc used for grading: $ROOTPLC, a local release build, or PATH."""
    env = os.environ.get("ROOTPLC")
    if env:
        return env
    for name in ("rootplc.exe", "rootplc"):
        local = REPO / "target" / "release" / name
        if local.exists():
            return str(local)
    found = shutil.which("rootplc")
    if not found:
        raise SystemExit("rootplc not found: build it (cargo build --release) or set ROOTPLC")
    return found


@dataclass
class Task:
    id: str
    dir: Path
    meta: dict

    @property
    def prompt(self) -> str:
        return (self.dir / "prompt.md").read_text(encoding="utf-8")

    @property
    def weights(self) -> dict:
        return self.meta.get("scoring", {})


def load_tasks(ids: list[str] | None = None) -> list[Task]:
    tasks = []
    for d in sorted(p for p in TASKS.iterdir() if p.is_dir()):
        if ids and d.name not in ids:
            continue
        meta = tomllib.loads((d / "task.toml").read_text(encoding="utf-8"))
        tasks.append(Task(d.name, d, meta))
    return tasks


def run_rootplc(args: list[str], timeout: int = 120) -> dict:
    """Run rootplc with --json and return the parsed report."""
    try:
        p = subprocess.run([rootplc_binary(), *args, "--json"], capture_output=True, text=True,
                           encoding="utf-8", timeout=timeout)
    except subprocess.TimeoutExpired:
        return {"ok": False, "status": "timeout"}
    try:
        return json.loads(p.stdout)
    except json.JSONDecodeError:
        return {"ok": False, "status": "bad-output", "stderr": p.stderr[-2000:]}


def st_files(directory: Path) -> list[Path]:
    return sorted(directory.rglob("*.st")) if directory.exists() else []


@dataclass
class Grade:
    compiled: bool = False
    visible_passed: bool = False
    hidden_passed: int = 0
    hidden_total: int = 0
    verified_correct: bool = False
    # tasks with [grading] iec_clean = true: no portability warning either
    iec_clean: bool | None = None
    score: float = 0.0
    diagnostics: list = field(default_factory=list)
    hidden_failures: list = field(default_factory=list)

    def as_dict(self) -> dict:
        return self.__dict__.copy()


def _stage(src: list[Path], extra: list[Path]) -> tuple[Path, list[str]]:
    """Copy sources into a fresh directory; return it and the file arguments."""
    tmp = Path(tempfile.mkdtemp(prefix="plcbench-"))
    args = []
    for i, f in enumerate(src + extra):
        dst = tmp / f"{i:02d}_{f.name}"
        shutil.copyfile(f, dst)
        args.append(str(dst))
    return tmp, args


# [scope.vendor-forms]: warnings that mark a CODESYS / TwinCAT form (the
# corpus tool uses the same list for its IEC-clean figure)
PORTABILITY_CODES = {"RP0006", "RP0017", "RP0112", "RP0113"} | {f"RP{n:04d}" for n in range(115, 136)}


def grade(task: Task, src_dir: Path) -> Grade:
    """Grade the `.st` files under `src_dir` (the agent's `src/`)."""
    g = Grade()
    src = st_files(src_dir)
    hidden = task.dir / "hidden_tests.st"
    visible = task.dir / "visible_tests.st"
    if not src:
        return g
    tmp, files = _stage(src, [])
    try:
        rep = run_rootplc(["check", *files])
        g.compiled = bool(rep.get("ok"))
        g.diagnostics = rep.get("diagnostics", [])[:20]
        if task.meta.get("grading", {}).get("iec_clean"):
            g.iec_clean = g.compiled and not any(
                d.get("code") in PORTABILITY_CODES for d in rep.get("diagnostics", []))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if not g.compiled:
        return g
    for extra, is_hidden in ((visible, False), (hidden, True)):
        tmp, files = _stage(src, [extra])
        try:
            rep = run_rootplc(["test", *files], timeout=300)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        tests = rep.get("tests", [])
        if is_hidden:
            g.hidden_total = max(len(tests), 1) if rep.get("compiled") else _count_tests(hidden)
            g.hidden_passed = sum(1 for t in tests if t.get("passed"))
            g.hidden_failures = [t for t in tests if not t.get("passed")][:10]
        else:
            g.visible_passed = bool(rep.get("ok"))
    g.verified_correct = g.compiled and g.visible_passed and g.hidden_total > 0 and g.hidden_passed == g.hidden_total
    if g.iec_clean is False:
        # the task asks for strict IEC 61131-3: a vendor form is not verified-correct
        g.verified_correct = False
    w = task.weights
    g.score = round(
        w.get("compile", 0.1) * g.compiled
        + w.get("visible_tests", 0.2) * g.visible_passed
        + w.get("hidden_tests", 0.7) * (g.hidden_passed / g.hidden_total if g.hidden_total else 0),
        4,
    )
    return g


def _count_tests(path: Path) -> int:
    return sum(1 for line in path.read_text(encoding="utf-8").splitlines() if line.startswith("TEST "))
