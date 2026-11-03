"""Real-world PLC code corpus: fetch, extract and analyse with rootplc.

    python corpus/corpus.py sync       # fetch PLC sources only, extract, delete the clone (disk-light)
    python corpus/corpus.py sync --refresh=twincat   # re-fetch + re-extract one format (or =all)
    python corpus/corpus.py fetch      # shallow-clone every project into corpus/.cache
    python corpus/corpus.py analyse    # extract ST, run rootplc check, write the report + dashboard
    python corpus/corpus.py dashboard  # rebuild corpus/dashboard.html from the last analysis

Writes corpus/REPORT.md and <cache>/analysis.json (cache: $ROOTPLC_CORPUS_CACHE or corpus/.cache). Code is never
copied into the repository (see manifest.toml).
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import tomllib
import xml.etree.ElementTree as ET
from collections import Counter
from datetime import date
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
# Where code is cloned and extracted; set ROOTPLC_CORPUS_CACHE to keep it on
# another disk (it grows with the corpus). Default: corpus/.cache.
CACHE = Path(os.environ.get("ROOTPLC_CORPUS_CACHE") or HERE / ".cache")
SYNTAX_CODES = {f"RP{n:04d}" for n in list(range(1, 17)) + [201, 202, 301]}

# Constructs RootPLC does not support yet (counted in extracted code). Keep in
# step with the RULES list in crates/rootplc-driver/src/coverage.rs.
FEATURES = {
    "VAR_INST / VAR_STAT": r"\bVAR_(INST|STAT)\b",
    "UNION": r"\bUNION\b",
    "SIZEOF": r"\bSIZEOF\s*\(",
    "__ system calls": r"\b__(?!ISVALIDREF)[A-Z]+\s*\(",
    "vendor pragmas {..}": r"\{(?!attribute)[a-z_]+",
    "__SYSTEM types": r"\b__SYSTEM\.",
}


def projects() -> list[dict]:
    return tomllib.loads((HERE / "manifest.toml").read_text(encoding="utf-8"))["project"]


def fetch() -> None:
    CACHE.mkdir(exist_ok=True)
    for p in projects():
        dst = CACHE / p["name"] / "repo"
        if dst.exists():
            print(f"have  {p['name']}")
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        r = subprocess.run(["git", "clone", "--depth", "1", "--quiet", p["url"], str(dst)], capture_output=True, text=True)
        print(("fetch " if r.returncode == 0 else "FAIL  ") + p["name"] + (" " + r.stderr.strip()[:100] if r.returncode else ""))


# Files each format needs; sync checks out only these (sparse, blobless clone).
SOURCES = {
    "twincat": ["*.TcPOU", "*.TcDUT", "*.TcGVL", "*.TcIO", "*.plcproj"],
    "brx": ["*.st", "*.fun", "*.typ", "*.var"],
    "st": ["*.st"],
}


def sync(refresh: str = "") -> None:
    """Fetch only the PLC source files of each project, extract the units and
    delete the clone, so the cache holds just the extracted text. Projects
    already extracted are skipped; clones left by `fetch` are pruned.
    refresh="all" or a format name ("twincat") re-fetches and re-extracts
    those projects, e.g. after an extractor fix. Clones go to a local temp
    folder (git refuses repositories on exFAT disks); the extracted units are
    replaced only when a new extraction succeeded."""
    import tempfile
    CACHE.mkdir(exist_ok=True)
    tmp_root = Path(os.environ.get("ROOTPLC_CORPUS_TMP") or tempfile.gettempdir()) / "rootplc-corpus-clones"
    tmp_root.mkdir(parents=True, exist_ok=True)
    for p in projects():
        if p["format"] in ("binary", "none"):
            continue
        base = CACHE / p["name"]
        old_repo, done = base / "repo", base / "extracted"
        if old_repo.exists():  # a clone left by fetch or an interrupted sync
            shutil.rmtree(old_repo, onexc=_force_remove)
        if done.exists() and refresh not in ("all", p["format"]):
            continue
        repo = tmp_root / p["name"]
        if repo.exists():
            shutil.rmtree(repo, onexc=_force_remove)
        steps = [
            ["git", "-c", "core.longpaths=true", "clone", "--depth", "1", "--filter=blob:none", "--no-checkout", "--quiet", p["url"], str(repo)],
            ["git", "-C", str(repo), "-c", "core.longpaths=true", "sparse-checkout", "set", "--no-cone", *SOURCES[p["format"]]],
            ["git", "-C", str(repo), "-c", "core.longpaths=true", "checkout", "--quiet"],
        ]
        err = ""
        for cmd in steps:
            r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
            if r.returncode:
                err = r.stderr.strip()[:120]
                break
        if err:
            print(f"FAIL  {p['name']}: {err}", flush=True)
        else:
            base.mkdir(parents=True, exist_ok=True)
            n = len(list(extract(p, repo).rglob("*.st")))
            print(f"sync  {p['name']:44} {n:5} units", flush=True)
        if repo.exists():
            shutil.rmtree(repo, onexc=_force_remove)


def _force_remove(func, path, _exc):
    """Git marks pack files read-only on Windows; clear the flag and retry."""
    import os
    import stat
    os.chmod(path, stat.S_IWRITE)
    func(path)


# ----------------------------------------------------------------- extraction

def files(root: Path, pattern: str) -> list[Path]:
    """Files under root matching pattern; directories named like files
    (e.g. an Eclipse plugin folder `...debug.st`) are skipped."""
    return sorted(f for f in long_path(root).rglob(pattern) if f.is_file())


def long_path(p: Path) -> Path:
    r"""On Windows, paths over 260 characters need the \\?\ prefix (TwinCAT
    projects nest deeply); elsewhere the path is returned unchanged."""
    prefix = "\\\\?\\"
    if os.name != "nt" or str(p).startswith(prefix):
        return p
    return Path(prefix + str(p.resolve()))


def text_of(el) -> str:
    return (el.text or "") if el is not None else ""


def twincat_units(path: Path) -> list[tuple[str, str]]:
    """ST text of one .TcPOU / .TcDUT / .TcGVL file, as (unit name, source)."""
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return []
    out = []
    for kind in ("POU", "DUT", "GVL", "Itf"):
        for el in root.iter(kind):
            name = el.get("Name", path.stem)
            decl = text_of(el.find("Declaration")).strip()
            body = text_of(el.find("Implementation/ST")).strip()
            parts = [decl]
            for m in el.iter("Method"):
                parts.append(text_of(m.find("Declaration")).strip())
                parts.append(text_of(m.find("Implementation/ST")).strip())
                parts.append("END_METHOD")
            for pr in el.iter("Property"):
                parts.append(text_of(pr.find("Declaration")).strip())
                for acc in ("Get", "Set"):
                    a = pr.find(acc)
                    if a is not None:
                        # GET/SET with their own declarations ([pous.oop.property])
                        parts.append(acc.upper())
                        parts.append(text_of(a.find("Declaration")).strip())
                        parts.append(text_of(a.find("Implementation/ST")).strip())
                        parts.append("END_" + acc.upper())
                parts.append("END_PROPERTY")
            if kind == "POU":
                # [pous.action]: actions as ACTION name: ... END_ACTION
                for act in el.iter("Action"):
                    parts.append(f"ACTION {act.get('Name', 'Action')}:")
                    parts.append(text_of(act.find("Implementation/ST")).strip())
                    parts.append("END_ACTION")
                # the declaration may start with comments or {attribute} pragmas
                code = re.sub(r"\(\*.*?\*\)|/\*.*?\*/|//[^\n]*|\{[^}]*\}", " ", decl, flags=re.S)
                m = re.match(r"\s*(FUNCTION_BLOCK|FUNCTION|PROGRAM)\b", code, re.I)
                first = m.group(1).upper() if m else ""
                end = {"PROGRAM": "END_PROGRAM", "FUNCTION": "END_FUNCTION",
                       "FUNCTION_BLOCK": "END_FUNCTION_BLOCK"}.get(first, "")
                parts.insert(1, body)
                if end:
                    parts.append(end)
            elif kind == "Itf":
                parts.append("END_INTERFACE")
            out.append((f"{kind}_{name}", "\n".join(x for x in parts if x) + "\n"))
    return out


def brx_units(repo: Path) -> list[tuple[str, str]]:
    """B&R: types from .typ, function declarations from .fun joined with bodies from .st."""
    decls: dict[str, str] = {}
    out = []
    for f in files(repo, "*.fun"):
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"(?is)\b(FUNCTION_BLOCK|FUNCTION)\s+(\w+)(.*?)\bEND_\1\b", text):
            decls[m.group(2).upper()] = m.group(0)[: -len("END_" + m.group(1))]
    for f in files(repo, "*.typ"):
        out.append((f"TYPE_{f.stem}", f.read_text(encoding="utf-8", errors="replace")))
    for f in files(repo, "*.st"):
        text = f.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"(?is)\b(FUNCTION_BLOCK|FUNCTION)\s+(\w+)(.*?)\bEND_\1\b", text):
            name = m.group(2).upper()
            body = m.group(3)
            if name in decls:
                out.append((name, decls[name] + "\n" + body + "\nEND_" + m.group(1).upper() + "\n"))
            else:
                out.append((name, m.group(0) + "\n"))
    return out


def plcproj_libraries(project_dir: Path) -> list[str]:
    """Library names a TwinCAT project references (PlaceholderReference /
    LibraryReference in its .plcproj)."""
    out: list[str] = []
    for f in files(project_dir, "*.plcproj"):
        if f.parent != project_dir:
            continue
        try:
            root = ET.parse(f).getroot()
        except ET.ParseError:
            continue
        for el in root.iter():
            tag = el.tag.rsplit("}", 1)[-1]
            if tag in ("PlaceholderReference", "LibraryReference") and el.get("Include"):
                name = el.get("Include").split(",")[0].strip()
                if name and name not in out:
                    out.append(name)
    return out


def extract(p: dict, repo: Path | None = None) -> Path:
    """Extract the units of a cloned project into <cache>/<name>/extracted.
    Writes to a new folder first and swaps it in, so a failure never leaves
    the project without its previous units."""
    repo = repo or CACHE / p["name"] / "repo"
    final = CACHE / p["name"] / "extracted"
    dst = CACHE / p["name"] / "extracted.new"
    shutil.rmtree(dst, ignore_errors=True)
    dst.mkdir(parents=True)
    units: list[tuple[str, str]] = []
    groups: list[str] = []
    if p["format"] == "twincat":
        # a repository may hold several PLC projects (each with a .plcproj);
        # each gets its own folder so that its MAIN does not collide with
        # another project's MAIN
        projs = sorted({f.parent for f in files(repo, "*.plcproj")}, key=lambda x: -len(str(x)))
        for f in sorted(files(repo, "*")):
            if f.suffix in (".TcPOU", ".TcDUT", ".TcGVL", ".TcIO"):
                owner = next((pj for pj in projs if pj in f.parents), None)
                found = twincat_units(f)
                units += found
                groups += [str(owner) if owner else ""] * len(found)
    elif p["format"] == "brx":
        units = brx_units(repo)
    else:
        for f in sorted(files(repo, "*.st")):
            units.append((f.stem, f.read_text(encoding="utf-8", errors="replace")))
    distinct = sorted(set(groups))
    split = len(distinct) > 1

    def folder_of(g: str) -> Path:
        if not split:
            return dst
        label = Path(g).name if g else "_shared"
        f = dst / f"{re.sub(r'[^A-Za-z0-9_.-]', '_', label)[:40]}_{distinct.index(g)}"
        f.mkdir(exist_ok=True)
        return f

    # [compatibility libraries]: the libraries each project references,
    # read from its .plcproj (out of band, never from POU source)
    if p["format"] == "twincat":
        for pj in projs:
            refs = plcproj_libraries(pj)
            if refs and (str(pj) in distinct or not split):
                (folder_of(str(pj)) / "libraries.txt").write_text(chr(10).join(refs) + chr(10), encoding="utf-8")
    seen = Counter()
    for k, (name, src) in enumerate(units):
        folder = folder_of(groups[k]) if split else dst
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", name)[:80]
        key = (str(folder), safe)
        seen[key] += 1
        fname = safe + (f"_{seen[key]}" if seen[key] > 1 else "") + ".st"
        (folder / fname).write_text(src, encoding="utf-8")
    shutil.rmtree(final, ignore_errors=True)
    dst.rename(final)
    return final


# ----------------------------------------------------------------- analysis

def rootplc() -> str:
    for n in ("rootplc.exe", "rootplc"):
        if (REPO / "target" / "release" / n).exists():
            return str(REPO / "target" / "release" / n)
    return shutil.which("rootplc") or sys.exit("build rootplc first: cargo build --release")


def shipped_libraries(exe: str) -> dict[str, str]:
    """Compatibility libraries this rootplc bundles: lower-case name -> name."""
    r = subprocess.run([exe, "libraries", "--json"], capture_output=True, text=True, encoding="utf-8")
    try:
        return {l["name"].lower(): l["name"] for l in json.loads(r.stdout)["libraries"]}
    except (ValueError, KeyError):
        return {}


def libraries_for(folder: Path, fmt: str, shipped: dict[str, str]) -> list[str]:
    """The bundled libraries a project folder activates: those its .plcproj
    references (libraries.txt, see extract) plus TwinCAT_BuiltIns for every
    TwinCAT project. Out of band only; never inferred from the code."""
    refs = []
    lt = folder / "libraries.txt"
    if lt.exists():
        refs = [x.strip() for x in lt.read_text(encoding="utf-8").split() if x.strip()]
    libs = [shipped[r.lower()] for r in refs if r.lower() in shipped]
    if fmt == "twincat" and "twincat_builtins" in shipped:
        libs.append(shipped["twincat_builtins"])
    return sorted(set(libs))


def analyse() -> None:
    exe = rootplc()
    shipped = shipped_libraries(exe)
    results = []
    all_codes, all_features = Counter(), Counter()
    for p in projects():
        if p["format"] in ("binary", "none"):
            continue
        if (CACHE / p["name"] / "extracted").exists():
            d = CACHE / p["name"] / "extracted"
        elif (CACHE / p["name"] / "repo").exists():
            d = extract(p)
        else:
            print(f"skip {p['name']} (not fetched)")
            continue
        files = sorted(d.rglob("*.st"))
        feats = Counter()
        lines = 0
        for f in files:
            text = f.read_text(encoding="utf-8")
            lines += text.count("\n")
            for k, rx in FEATURES.items():
                if re.search(rx, text, re.M | re.I):
                    feats[k] += 1
        # one check per sub-project folder (see extract); files directly in d
        # form a project of their own
        subdirs = sorted(x for x in d.iterdir() if x.is_dir())
        targets = [([str(x)], x) for x in subdirs]
        top = [str(f) for f in files if f.parent == d]
        if top and not subdirs:
            targets.append(([str(d)], d))  # one project: pass the folder (short command line)
        elif top:
            targets.append((top, d))
        per_file: dict[str, list] = {}
        for t, folder in targets:
            libs = libraries_for(folder, p["format"], shipped)
            extra = ["--library", ",".join(libs)] if libs else []
            r = subprocess.run([exe, "check", *t, *extra, "--json"], capture_output=True, text=True, encoding="utf-8")
            rep = json.loads(r.stdout) if r.stdout.strip().startswith("{") else {}
            for diag in rep.get("diagnostics", []):
                if diag["severity"] == "error":
                    key = str(Path(diag["file"]).resolve())
                    per_file.setdefault(key, []).append(diag)
        key_of = {f: str(f.resolve()) for f in files}
        syntax_ok = sum(1 for f in files if not any(x["code"] in SYNTAX_CODES or x["code"] == "RP0004"
                                                    for x in per_file.get(key_of[f], [])))
        clean = sum(1 for f in files if key_of[f] not in per_file)
        codes = Counter(x["code"] for xs in per_file.values() for x in xs)
        msgs = Counter(re.sub(r"'[^']*'", "'…'", x["message"]) for xs in per_file.values() for x in xs)
        all_codes.update(codes)
        all_features.update(feats)
        results.append({"name": p["name"], "url": p["url"], "licence": p["licence"], "redistribute": p["redistribute"],
                        "kind": p.get("kind", ""), "units": len(files), "lines": lines, "syntax_ok": syntax_ok,
                        "clean": clean, "codes": codes.most_common(8), "messages": msgs.most_common(6),
                        "features": dict(feats)})
        print(f"{p['name']:30} units {len(files):5}  syntax ok {syntax_ok:5}  clean {clean:5}")
    (CACHE / "analysis.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
    record_history(results)
    write_report(results, all_codes, all_features)


def pct(a, b):
    return f"{100 * a / b:.0f}%" if b else "n/a"


def write_report(results, all_codes, all_features) -> None:
    U = sum(r["units"] for r in results)
    L = sum(r["lines"] for r in results)
    S = sum(r["syntax_ok"] for r in results)
    C = sum(r["clean"] for r in results)
    out = [
        "# Real-world PLC code corpus: what rootplc handles today",
        "",
        f"*Generated {date.today():%Y-%m-%d} by `corpus/corpus.py`. {len(results)} public projects, "
        f"{U} program units (POUs, types, global lists), {L:,} lines of Structured Text.*",
        "",
        "A unit is *syntax OK* when rootplc lexes and parses it; *clean* when it also passes the type",
        "checker with no errors. Units are checked per project, so references to other libraries that",
        "are not in the corpus count as errors.",
        "",
        f"**Overall: syntax OK {pct(S, U)} · clean {pct(C, U)}.**",
        "",
        "| Project | Kind | Licence | Units | Lines | Syntax OK | Clean |",
        "|---|---|---|---|---|---|---|",
    ]
    for r in sorted(results, key=lambda r: -r["units"]):
        out.append(f"| [{r['name']}]({r['url']}) | {r['kind']} | {r['licence']} | {r['units']} | {r['lines']:,} | "
                   f"{pct(r['syntax_ok'], r['units'])} | {pct(r['clean'], r['units'])} |")
    out += ["", "## What blocks the rest", "", "Units using each construct RootPLC does not support yet:", "",
            "| Construct | Units |", "|---|---|"]
    for k, v in all_features.most_common():
        out.append(f"| {k} | {v} ({pct(v, U)}) |")
    out += ["", "Most frequent error codes:", "", "| Code | Count |", "|---|---|"]
    for k, v in all_codes.most_common(12):
        out.append(f"| {k} | {v} |")
    skipped = [p for p in projects() if p["format"] in ("binary", "none")]
    if skipped:
        out += ["", "## Listed but not analysed", "", "| Project | Reason |", "|---|---|"]
        out += [f"| [{p['name']}]({p['url']}) | {p.get('note', p['format'])} |" for p in skipped]
    out += ["", "## Licences", "",
            "Only projects marked redistributable (MIT, BSD, Apache, CC0, Unlicense) may be copied into a",
            "published dataset. The others are analysed locally and cited by link.", ""]
    (HERE / "REPORT.md").write_text("\n".join(out), encoding="utf-8")
    print(f"wrote {HERE / 'REPORT.md'}")


def record_history(results) -> None:
    """Append this run's totals to corpus/history.json (public metrics only)."""
    from datetime import datetime
    U = sum(r["units"] for r in results) or 1
    row = {"date": datetime.now().strftime("%Y-%m-%d %H:%M"), "units": U,
           "parse": round(100 * sum(r["syntax_ok"] for r in results) / U),
           "clean": round(100 * sum(r["clean"] for r in results) / U)}
    path = HERE / "history.json"
    hist = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    if not hist or (hist[-1]["units"], hist[-1]["parse"], hist[-1]["clean"]) != (row["units"], row["parse"], row["clean"]):
        hist.append(row)
    path.write_text(json.dumps(hist, indent=1), encoding="utf-8")


def dashboard() -> None:
    """Write corpus/dashboard.html (self-contained) from the last analysis."""
    results = json.loads((CACHE / "analysis.json").read_text(encoding="utf-8"))
    feats = Counter()
    for r in results:
        feats.update(r["features"])
    version = subprocess.run([rootplc(), "--version"], capture_output=True, text=True).stdout.strip().replace("rootplc ", "")
    hist_path = HERE / "history.json"
    data = {
        "date": date.today().strftime("%d %b %Y"),
        "listed": len(projects()),
        "rootplc": version,
        "projects": [{k: r[k] for k in ("name", "licence", "units", "lines", "syntax_ok", "clean")} for r in results],
        "features": feats.most_common(),
        "history": json.loads(hist_path.read_text(encoding="utf-8")) if hist_path.exists() else [],
    }
    page = (HERE / "dashboard_template.html").read_text(encoding="utf-8").replace("__DATA__", json.dumps(data).replace("</", "<\\/"))
    (HERE / "dashboard.html").write_text(page, encoding="utf-8")
    print(f"wrote {HERE / 'dashboard.html'}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else ""
    if cmd == "sync":
        sync(sys.argv[2].removeprefix("--refresh=") if len(sys.argv) > 2 else "")
    elif cmd == "fetch":
        fetch()
    elif cmd in ("analyse", "analyze"):
        analyse()
        dashboard()
    elif cmd == "dashboard":
        dashboard()
    else:
        print(__doc__)
