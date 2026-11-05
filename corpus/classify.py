"""Block-catalog classifier v1 (spec/15-blocks.md, blocks/README.md).

Classifies every FUNCTION_BLOCK and FUNCTION of the corpus core set into the
twelve RootBlocks job families (F01-F12) and, for the first families, into
block kinds, from three signals:

- words of the name (camelCase and underscores split, so "statement" is not
  "state"), weight 3;
- words of the interface variables (VAR_INPUT / VAR_OUTPUT / VAR_IN_OUT),
  weight 2;
- standard blocks and constructs used in the body (TON, CTU, MC_..., a CASE
  over a step variable, ...), weight 1.

A unit is classified when its best family scores at least 3. Holdout
projects are skipped without being read. Output is aggregate only
(counts per family and kind); code is never copied.

Usage:  python corpus/classify.py        (needs the corpus cache: corpus.py fetch / analyse)
Writes: corpus/BLOCKS_REPORT.md, <cache>/blocks.json and <cache>/units.json (one
entry per classified unit: project, file, name, family, kind, category, licence;
it stays in the cache, the starting list of the R2 verified layer)
"""
from __future__ import annotations

import json
import os
import re
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
CACHE = Path(os.environ.get("ROOTPLC_CORPUS_CACHE") or HERE / ".cache")

FAMILIES = {
    "F01": "Signal conditioning",
    "F02": "Discrete logic and interlocks",
    "F03": "Timing, counting, scheduling",
    "F04": "Device modules",
    "F05": "Sequencing",
    "F06": "Closed-loop control",
    "F07": "Motion",
    "F08": "Alarms and events",
    "F09": "Supervision and diagnostics",
    "F10": "Machine modes and states",
    "F11": "Data handling and communication",
    "F12": "Material handling and process patterns",
}

# words of names and interfaces that point to a family
WORDS = {
    "F01": "scale scaling scaled filter debounce deadband ramp limit limiter clamp average avg smooth "
           "lowpass pt1 integrator integral totalizer totaliser linearize normalize analog analogue ai raw eng "
           "sensor signal measurement measure",
    "F02": "interlock permissive latch flipflop toggle lock bistable",
    "F03": "timer delay pulse blink clock counter count hours hour schedule scheduler calendar time "
           "runtime duration",
    "F04": "motor valve cylinder pump fan heater drive vfd inverter actuator solenoid contactor lamp light "
           "relay gripper damper brake",
    "F05": "sequence sequencer step steps chain sfc phase batch recipe procedure homing state statemachine "
           "fsm transition",
    "F06": "pid pi pd controller regulator hysteresis setpoint sp pv cv kp ki kd tn tv loop cascade ratio "
           "thermostat",
    "F07": "axis motion servo stepper position positioning jog cam move encoder velocity acceleration mc",
    "F08": "alarm alarms alert event events warning fault faults ack acknowledge message diag annunciator",
    "F09": "watchdog heartbeat timeout monitor supervision health oee statistic statistics maintenance "
           "diagnostic",
    "F10": "mode modes packml machine manual auto automatic estop emergency operating unit",
    "F11": "buffer fifo lifo queue stack string convert conversion crc checksum log logger modbus tcp udp "
           "serial json xml mqtt opc socket file array sort list map byte bytes parse format",
    "F12": "conveyor belt tank level fill filling dosing dose weigh weighing pallet palletizer sorter "
           "station transfer traffic elevator crane mixer lift",
}
WORDS = {f: set(ws.split()) for f, ws in WORDS.items()}

# constructs in the body
BODY = {
    "F03": [r"\bTON\b", r"\bTOF\b", r"\bTP\b", r"\bCTU\b", r"\bCTD\b", r"\bCTUD\b"],
    "F02": [r"\bRS\b", r"\bSR\b", r"\bR_TRIG\b", r"\bF_TRIG\b"],
    "F07": [r"\bMC_\w+", r"\bAXIS_REF\b"],
    "F05": [r"CASE\s+\w*(step|state)\w*\s+OF"],
    "F11": [r"\bMEMCPY\b", r"\bSIZEOF\b", r"\bCONCAT\b", r"\bFIND\b", r"\bMID\b"],
    "F06": [r"\bPID\w*\b"],
}

# block kinds for the first families (F04, F01): any name word
KINDS = {
    "F04": {"motor": "motor", "valve": "valve", "cylinder": "cylinder", "pump": "pump", "fan": "fan",
            "heater": "heater", "drive": "drive / VFD", "vfd": "drive / VFD", "inverter": "drive / VFD",
            "lamp": "lamp / light", "light": "lamp / light", "gripper": "gripper", "solenoid": "valve",
            "contactor": "motor", "damper": "damper", "brake": "brake"},
    "F01": {"scale": "scaling", "scaling": "scaling", "scaled": "scaling", "filter": "filter",
            "lowpass": "filter", "pt1": "filter", "average": "average", "avg": "average",
            "debounce": "debounce", "deadband": "deadband", "ramp": "ramp", "limit": "limit / clamp",
            "limiter": "limit / clamp", "clamp": "limit / clamp", "integrator": "integrator / totaliser",
            "totalizer": "integrator / totaliser", "totaliser": "integrator / totaliser",
            "analog": "analog input", "analogue": "analog input", "ai": "analog input",
            "sensor": "sensor validation"},
}

POU = re.compile(r"^\s*(FUNCTION_BLOCK|FUNCTION)\s+(?:(?:PUBLIC|PRIVATE|INTERNAL|ABSTRACT|FINAL)\s+)*"
                 r"([A-Za-z_]\w*)(.*?)^\s*END_\1\b", re.I | re.M | re.S)
SECTION = re.compile(r"\b(VAR_INPUT|VAR_OUTPUT|VAR_IN_OUT)\b(.*?)\bEND_VAR\b", re.I | re.S)
COMMENT = re.compile(r"\(\*.*?\*\)|//[^\n]*", re.S)


def words(name: str) -> list[str]:
    """Split an identifier into lower-case words: camelCase, digits, underscores."""
    parts = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", name)
    parts = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", parts)
    return [w for w in re.split(r"[^A-Za-z0-9]+", parts.lower()) if w]


def strip_prefix(ws: list[str]) -> list[str]:
    """Drop naming-convention prefixes such as fb, fc, f, i, b, n, st."""
    return [w for w in ws if w not in {"fb", "fc", "fun", "f", "fnc", "i", "o", "b", "n", "st", "e", "r",
                                       "s", "x", "q", "in", "out", "t"}]


TEST_WORDS = {"test", "tests", "assert", "mock", "fixture", "stub", "fake", "spy"}


def classify(name: str, decl: str, body: str) -> tuple[str | None, dict[str, int], list[str]]:
    score: dict[str, int] = defaultdict(int)
    nw = strip_prefix(words(name))
    if TEST_WORDS & set(words(name)):
        return "TEST", {}, nw
    for f, ws in WORDS.items():
        score[f] += 3 * sum(1 for w in nw if w in ws)
    iface = []
    for m in SECTION.finditer(decl):
        for line in m.group(2).splitlines():
            v = line.split(":")[0].strip()
            if v and re.match(r"^[A-Za-z_]\w*$", v):
                iface.extend(strip_prefix(words(v)))
    for f, ws in WORDS.items():
        score[f] += 2 * min(3, sum(1 for w in iface if w in ws))
    for f, pats in BODY.items():
        score[f] += sum(1 for p in pats if re.search(p, body, re.I))
    best = max(score.items(), key=lambda kv: kv[1]) if score else (None, 0)
    return (best[0] if best[1] >= 3 else None), dict(score), nw


def main() -> None:
    analysis = json.loads((CACHE / "analysis.json").read_text(encoding="utf-8"))
    core = {p["name"]: p for p in analysis if not p["holdout"]}
    fam = Counter()
    fam_apps = Counter()
    fam_projects: dict[str, set] = defaultdict(set)
    kinds: dict[str, Counter] = defaultdict(Counter)
    total = classified = tests = 0
    kinds_total = Counter()
    units: list[dict] = []
    for name, p in sorted(core.items()):
        root = CACHE / name
        if not root.exists():
            continue
        for f in root.rglob("*.st"):
            try:
                text = COMMENT.sub(" ", f.read_text(encoding="utf-8", errors="replace"))
            except OSError:
                continue
            for m in POU.finditer(text):
                total += 1
                pou_name, rest = m.group(2), m.group(3)
                cut = rest.rfind("END_VAR")
                decl, body = (rest[:cut], rest[cut:]) if cut >= 0 else ("", rest)
                f_id, _, nw = classify(pou_name, decl, body)
                if f_id == "TEST":
                    tests += 1
                    total -= 1
                    continue
                if f_id is None:
                    continue
                classified += 1
                fam[f_id] += 1
                fam_projects[f_id].add(name)
                if p["category"] == "application":
                    fam_apps[f_id] += 1
                k = None
                if f_id in KINDS:
                    k = next((KINDS[f_id][w] for w in nw if w in KINDS[f_id]), "other")
                    kinds[f_id][k] += 1
                    kinds_total[f_id] += 1
                units.append({"project": name, "file": f.relative_to(root).as_posix(),
                              "name": pou_name, "pou": m.group(1).upper(), "family": f_id,
                              "kind": k, "category": p["category"], "licence": p.get("licence", ""),
                              "redistribute": bool(p.get("redistribute"))})

    out = {"units": total, "classified": classified, "test_units": tests,
           "families": {f: {"units": fam[f], "projects": len(fam_projects[f]), "applications": fam_apps[f]}
                        for f in FAMILIES},
           "kinds": {f: dict(c) for f, c in kinds.items()}}
    (CACHE / "blocks.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
    (CACHE / "units.json").write_text(json.dumps(units, indent=0), encoding="utf-8")

    lines = [
        "# Block catalog: real code by job family",
        "",
        "Generated by `corpus/classify.py` (classifier v1) from the corpus core set; holdout projects are",
        "not read. Each FUNCTION_BLOCK and FUNCTION is scored by the words of its name (weight 3), the",
        "words of its interface (weight 2) and the standard blocks its body uses (weight 1), and assigned",
        "to the best of the twelve RootBlocks families when that scores at least 3. Aggregate counts only;",
        "no code is copied. Families and blocks: [../blocks/README.md](../blocks/README.md).",
        f"Test code ({tests:,} units named test, assert, mock, ...) is counted apart and left out.",
        "",
        f"**{classified:,} of {total:,} blocks and functions classified ({100 * classified / max(total, 1):.0f}%).**",
        "",
        "| Family | Units | Projects | In applications |",
        "|---|---:|---:|---:|",
    ]
    for f, title in sorted(FAMILIES.items(), key=lambda kv: -fam[kv[0]]):
        lines.append(f"| {f} {title} | {fam[f]:,} | {len(fam_projects[f])} | {fam_apps[f]:,} |")
    for f in ("F04", "F01"):
        lines += ["", f"**{f} {FAMILIES[f]} by kind** ({kinds_total[f]:,} units)", "",
                  "| Kind | Units |", "|---|---:|"]
        for k, n in kinds[f].most_common():
            lines.append(f"| {k} | {n:,} |")
    (HERE / "BLOCKS_REPORT.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"classified {classified} of {total}; wrote corpus/BLOCKS_REPORT.md")


if __name__ == "__main__":
    main()
