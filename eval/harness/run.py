"""Agent evaluation harness (WP E2).

Runs agent hosts on bench tasks, with and without RootPLC, and grades the
results with the hidden tests:

    python eval/harness/run.py --hosts reference,empty --modes with,without
    python eval/harness/run.py --hosts claude-code --tasks latch-start-stop --modes with

Per task and mode the harness
1. creates a fresh workspace: `src/` (empty), `tests/visible_tests.st`, `PROMPT.md`;
   in mode `with` also `AGENTS.md`, `rootplc.toml` and the host's MCP config,
   and `rootplc` on PATH; in mode `without`, `rootplc` is not on PATH;
2. starts the host non-interactively (command from `eval/hosts/<host>.toml`);
3. grades `src/` (compile, visible, hidden = verified-correct), measures the
   mutation score of the agent's own tests in `tests/`, and detects whether the
   agent used rootplc ("pick");
4. writes `eval/results/<run>/<host>/<mode>/<task>.json` and `summary.json`.

Built-in hosts for validating the pipeline without an agent:
`reference` (copies the reference solution) and `empty` (does nothing).
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import tomllib
from datetime import datetime, timezone
from pathlib import Path

from bench import REPO, Task, grade, load_tasks, rootplc_binary, st_files
from mutate import mutation_score

HOSTS = REPO / "eval" / "hosts"
RESULTS = REPO / "eval" / "results"
AGENTS_MD = REPO / "agent" / "templates" / "AGENTS.md"
PICK_MARKERS = ("rootplc check", "rootplc test", "rootplc run", "rootplc explain", "rootplc_check",
                "rootplc_test", "rootplc_run", "rootplc_explain")


def load_host(name: str) -> dict:
    if name in ("reference", "empty"):
        return {"name": name, "builtin": True}
    path = HOSTS / f"{name}.toml"
    if not path.exists():
        raise SystemExit(f"no host config {path}")
    cfg = tomllib.loads(path.read_text(encoding="utf-8"))
    if not (cfg.get("command") or (cfg.get("command_with") and cfg.get("command_without"))):
        raise SystemExit(f"{path}: 'command' is not set; this host is not configured yet")
    return cfg


def make_workspace(task: Task, mode: str, host: dict) -> Path:
    ws = Path(tempfile.mkdtemp(prefix=f"plceval-{task.id}-"))
    (ws / "src").mkdir()
    (ws / "tests").mkdir()
    shutil.copyfile(task.dir / "visible_tests.st", ws / "tests" / "visible_tests.st")
    (ws / "PROMPT.md").write_text(task.prompt, encoding="utf-8")
    if mode == "with":
        shutil.copyfile(AGENTS_MD, ws / "AGENTS.md")
        (ws / "rootplc.toml").write_text(f'[project]\nname = "{task.id}"\nversion = "0.1.0"\nspec = "0"\n',
                                         encoding="utf-8")
        for rel, text in host.get("with_files", {}).items():
            p = ws / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text, encoding="utf-8")
    return ws


def agent_env(mode: str) -> dict:
    env = os.environ.copy()
    exe = Path(rootplc_binary()).resolve()
    parts = [p for p in env.get("PATH", "").split(os.pathsep)
             if p and not (Path(p) / exe.name).exists()]   # never leak rootplc in mode without
    if mode == "with":
        parts.insert(0, str(exe.parent))
    env["PATH"] = os.pathsep.join(parts)
    env.pop("ROOTPLC", None)
    return env


def run_agent(task: Task, host: dict, mode: str, ws: Path, timeout: int) -> tuple[str, float, int]:
    start = time.monotonic()
    if host.get("builtin"):
        if host["name"] == "reference":
            for f in st_files(task.dir / "reference"):
                shutil.copyfile(f, ws / "src" / f.name)
        return "", 0.0, 0
    prompt = task.prompt
    if mode == "with" and host.get("prompt_suffix_with"):
        prompt += "\n" + host["prompt_suffix_with"]
    command = host.get(f"command_{mode}") or host["command"]
    args = [a.replace("{prompt}", prompt).replace("{workdir}", str(ws)) for a in command]
    if host.get("model"):
        args += host.get("model_flag", ["--model"]) + [host["model"]]
    try:
        p = subprocess.run(args, cwd=ws, env=agent_env(mode), capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=timeout)
        out, code = p.stdout + "\n" + p.stderr, p.returncode
    except subprocess.TimeoutExpired as e:
        out, code = f"TIMEOUT after {timeout}s\n{e.stdout or ''}", -1
    except FileNotFoundError:
        raise SystemExit(f"host command not found: {args[0]} (is {host['name']} installed?)")
    return out, time.monotonic() - start, code


def evaluate(task: Task, host: dict, mode: str, timeout: int, mutate: bool) -> dict:
    ws = make_workspace(task, mode, host)
    try:
        transcript, seconds, code = run_agent(task, host, mode, ws, timeout)
        g = grade(task, ws / "src")
        own_tests = [t for t in st_files(ws / "tests") if t.name != "visible_tests.st"]
        mut = None
        if mutate and g.compiled and own_tests:
            m = mutation_score(st_files(ws / "src"), own_tests)
            mut = {"viable": m.viable, "killed": m.killed, "score": round(m.score, 4)}
        picked = any(mk in transcript for mk in PICK_MARKERS)
        return {
            "task": task.id, "host": host["name"], "mode": mode, "seconds": round(seconds, 1),
            "exit_code": code, "picked_rootplc": picked, "own_test_files": len(own_tests),
            "mutation": mut, **g.as_dict(),
            "src": {f.name: f.read_text(encoding="utf-8", errors="replace") for f in st_files(ws / "src")},
            "transcript_tail": transcript[-20000:],
        }
    finally:
        shutil.rmtree(ws, ignore_errors=True)


def summarise(rows: list[dict]) -> dict:
    out = {}
    for r in rows:
        k = f"{r['host']}/{r['mode']}"
        s = out.setdefault(k, {"tasks": 0, "compiled": 0, "visible": 0, "verified_correct": 0, "score": 0.0,
                               "picked": 0, "with_own_tests": 0, "mutation_scores": []})
        s["tasks"] += 1
        s["compiled"] += r["compiled"]
        s["visible"] += r["visible_passed"]
        s["verified_correct"] += r["verified_correct"]
        s["score"] += r["score"]
        s["picked"] += r["picked_rootplc"]
        s["with_own_tests"] += r["own_test_files"] > 0
        if r["mutation"]:
            s["mutation_scores"].append(r["mutation"]["score"])
    for s in out.values():
        n = s["tasks"] or 1
        ms = s.pop("mutation_scores")
        s.update({"compile_rate": round(s["compiled"] / n, 4), "verified_correct_rate": round(s["verified_correct"] / n, 4),
                  "mean_score": round(s["score"] / n, 4), "pick_rate": round(s["picked"] / n, 4),
                  "mean_mutation_score": round(sum(ms) / len(ms), 4) if ms else None})
        s.pop("score")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--hosts", default="reference,empty")
    ap.add_argument("--modes", default="with,without")
    ap.add_argument("--tasks", default="", help="comma-separated task ids (default: all)")
    ap.add_argument("--repeat", type=int, default=1, help="runs per task (agents are not deterministic)")
    ap.add_argument("--timeout", type=int, default=900, help="seconds per agent run")
    ap.add_argument("--no-mutation", action="store_true")
    ap.add_argument("--run-id", default=datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S"))
    a = ap.parse_args()
    tasks = load_tasks([t for t in a.tasks.split(",") if t] or None)
    hosts = [load_host(h) for h in a.hosts.split(",") if h]
    modes = [m for m in a.modes.split(",") if m]
    out_dir = RESULTS / a.run_id
    rows = []
    for host in hosts:
        for mode in modes:
            for task in tasks:
                for rep in range(a.repeat):
                    r = evaluate(task, host, mode, a.timeout, not a.no_mutation)
                    r["repeat"] = rep
                    rows.append(r)
                    d = out_dir / host["name"] / mode
                    d.mkdir(parents=True, exist_ok=True)
                    (d / f"{task.id}.{rep}.json").write_text(json.dumps(r, indent=1), encoding="utf-8")
                    flag = "OK " if r["verified_correct"] else ("cmp" if r["compiled"] else "-- ")
                    print(f"[{flag}] {host['name']:12} {mode:8} {task.id:26} score {r['score']:.2f}"
                          f" pick={'y' if r['picked_rootplc'] else 'n'} {r['seconds']:.0f}s", flush=True)
    summary = {"run_id": a.run_id, "rootplc": rootplc_binary(), "tasks": [t.id for t in tasks],
               "repeat": a.repeat, "results": summarise(rows)}
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=1), encoding="utf-8")
    print(json.dumps(summary["results"], indent=1))
    print(f"results: {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
