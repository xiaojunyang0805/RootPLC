"""Real-world PLC code corpus: fetch, extract and analyse with rootplc.

    python corpus/corpus.py sync       # fetch PLC sources only, extract, delete the clone (disk-light)
    python corpus/corpus.py sync --refresh=twincat   # re-fetch + re-extract one format, =all, or =name,name
    python corpus/corpus.py fetch      # shallow-clone every project into corpus/.cache
    python corpus/corpus.py analyse    # extract ST, run rootplc check, write the report + dashboard
    python corpus/corpus.py dashboard  # rebuild corpus/dashboard.html from the last analysis
    python corpus/corpus.py run        # run smoke test: execute each clean application program

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
# Categories whose code is written to run on a PLC: the headline figures use
# these. "tool-input" (test inputs and examples of compilers, parsers, editors,
# AI tools, benchmarks) is analysed and reported on its own.
CORE = ("application", "library", "sample")

# Constructs RootPLC does not support yet (counted in extracted code). Keep in
# step with the RULES list in crates/rootplc-driver/src/coverage.rs.
FEATURES = {
    "VAR_STAT": r"\bVAR_STAT\b",
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
    refresh="all", a format name ("twincat") or project names (comma
    separated) re-fetches and re-extracts those projects, e.g. after an extractor fix. Clones go to a local temp
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
        wanted = set(refresh.split(","))
        if done.exists() and not wanted & {"all", p["format"], p["name"]}:
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
            elif kind == "GVL" and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", name):
                # a TwinCAT global variable list is named, and code reads its
                # variables as GVL_Name.x; the name lives only in the XML, so it
                # becomes a namespace around the list (IEC ed.3 [pous.namespace]:
                # qualified and unqualified access both resolve)
                parts = [f"NAMESPACE {name}"] + parts + ["END_NAMESPACE"]
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
        st_files = sorted(files(repo, "*.st"))
        texts = [f.read_text(encoding="utf-8", errors="replace") for f in st_files]
        # a repository of separate programs (examples, B&R tasks, benchmark
        # suites) declares the same names in different directories: then each
        # directory is checked on its own. A library that repeats a handful of
        # names (2 % in SRCI) is still one project: split only when at least
        # 5 % of the declared names repeat.
        seen_in: dict[str, set] = {}
        decl = re.compile(r"^\s*(?:PROGRAM|FUNCTION_BLOCK|FUNCTION|CLASS)\s+(\w+)", re.I | re.M)
        for f, t in zip(st_files, texts):
            for n in decl.findall(t):
                seen_in.setdefault(n.lower(), set()).add(f.parent)
        repeated = sum(1 for d in seen_in.values() if len(d) > 1)
        by_dir = repeated > 0 and repeated >= 0.05 * len(seen_in)
        for f, t in zip(st_files, texts):
            units.append((f.stem, t))
            groups.append(str(f.parent.relative_to(long_path(repo))) if by_dir else "")
    distinct = sorted(set(groups))
    split = len(distinct) > 1

    def folder_of(g: str) -> Path:
        if not split:
            return dst
        label = "_".join(Path(g).parts[-2:]) if g else "_shared"
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
    lib_ns, want = p.get("provides"), p.get("provides_folder", "")
    for k, (name, src) in enumerate(units):
        folder = folder_of(groups[k]) if split else dst
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", name)[:80]
        key = (str(folder), safe)
        seen[key] += 1
        fname = safe + (f"_{seen[key]}" if seen[key] > 1 else "") + ".st"
        if lib_ns and (not want or folder.name == want or folder.name.startswith(want + "_")):
            # a library's declarations live in its namespace (TcUnit.Test)
            src = f"NAMESPACE {lib_ns}" + chr(10) + src + chr(10) + "END_NAMESPACE" + chr(10)
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


def corpus_libraries() -> dict[str, Path]:
    """Libraries the corpus itself provides (manifest `provides`): lower-case
    name -> the folder of extracted units that implements it."""
    out: dict[str, Path] = {}
    for p in projects():
        name = p.get("provides")
        if not name:
            continue
        d = CACHE / p["name"] / "extracted"
        if not d.exists():
            continue
        want = p.get("provides_folder", "")
        subs = sorted(x for x in d.iterdir() if x.is_dir())
        match = next((x for x in subs if want and (x.name == want or x.name.startswith(want + "_"))), None)
        out[name.lower()] = match or d
    return out


def analyse() -> None:
    exe = rootplc()
    shipped = shipped_libraries(exe)
    provided = corpus_libraries()
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
        if p.get("granularity") == "file":
            # a collection of independent snippets: each file on its own
            subdirs = []
            targets = [([str(f)], f.parent) for f in files]
        top = [str(f) for f in files if f.parent == d] if p.get("granularity") != "file" else []
        if top and not subdirs:
            targets.append(([str(d)], d))  # one project: pass the folder (short command line)
        elif top:
            targets.append((top, d))
        # sub-project folders by the name other sub-projects reference them
        # with (folder label without its _<n> suffix, last part)
        siblings: dict[str, Path] = {}
        for x in subdirs:
            label = re.sub(r"_\d+$", "", x.name).lower()
            siblings.setdefault(label, x)
            siblings.setdefault(label.rsplit("_", 1)[-1], x)
        per_file: dict[str, list] = {}
        for t, folder in targets:
            libs = libraries_for(folder, p["format"], shipped)
            extra = ["--library", ",".join(libs)] if libs else []
            # libraries the corpus provides (e.g. TcUnit): checked alongside,
            # never counted for this project
            deps: list[str] = []
            todo, seen_dep = [folder], {folder}
            while todo:  # references of references too
                cur = todo.pop()
                lt = cur / "libraries.txt"
                for r in lt.read_text(encoding="utf-8").split() if lt.exists() else []:
                    # a library the corpus provides (TcUnit), or one this
                    # repository builds itself (TcOpen's TcoCore next to the
                    # projects using it)
                    dep = provided.get(r.lower()) or siblings.get(r.lower())
                    if not dep or dep in seen_dep or str(folder).startswith(str(dep) + os.sep):
                        continue
                    seen_dep.add(dep)
                    todo.append(dep)
                    deps.append(str(dep))
                    # what that library references is active too
                    libs = sorted(set(libs) | set(libraries_for(dep, p["format"], shipped)))
            extra = deps + (["--library", ",".join(libs)] if libs else [])
            r = subprocess.run([exe, "check", *t, *extra, "--json"], capture_output=True, text=True, encoding="utf-8")
            rep = json.loads(r.stdout) if r.stdout.strip().startswith("{") else {}
            # only the target's own files: a sibling checked alongside is
            # counted when its own folder is the target
            mine = {str(Path(x).resolve()) for x in t if Path(x).is_file()}
            roots = [str(Path(x).resolve()) + os.sep for x in t if Path(x).is_dir()]
            for diag in rep.get("diagnostics", []):
                if diag["severity"] == "error":
                    key = str(Path(diag["file"]).resolve())
                    if key in mine or any(key.startswith(r) for r in roots):
                        per_file.setdefault(key, []).append(diag)
        key_of = {f: str(f.resolve()) for f in files}
        # diagnostics in provided libraries checked alongside are not this project's
        own = set(key_of.values())
        per_file = {k: v for k, v in per_file.items() if k in own}
        syntax_ok = sum(1 for f in files if not any(x["code"] in SYNTAX_CODES or x["code"] == "RP0004"
                                                    for x in per_file.get(key_of[f], [])))
        clean = sum(1 for f in files if key_of[f] not in per_file)
        codes = Counter(x["code"] for xs in per_file.values() for x in xs)
        msgs = Counter(re.sub(r"'[^']*'", "'…'", x["message"]) for xs in per_file.values() for x in xs)
        # exact messages with one example place (cache only, never published)
        raw = Counter(f"{x['code']} {x['message']}" for xs in per_file.values() for x in xs)
        where = {}
        for k2, xs in per_file.items():
            for x in xs:
                where.setdefault(f"{x['code']} {x['message']}", f"{k2}:{x.get('line', 0)}")
        # which names are missing (cache only, to rank compatibility work)
        names = Counter(f"{x['code']} {m.group(1)}" for xs in per_file.values() for x in xs
                        if x["code"] in ("RP0201", "RP0111", "RP0203")
                        for m in [re.search(r"'([^']*)'", x["message"])] if m)
        holdout = bool(p.get("holdout"))
        # holdout projects measure overfitting: their errors are never ranked or
        # stored, so no fix is ever chosen by looking at them
        if not p.get("dialect") and not holdout and p.get("category") in CORE:
            all_codes.update(codes)
            all_features.update(feats)
        results.append({"name": p["name"], "url": p["url"], "licence": p["licence"], "redistribute": p["redistribute"],
                        "kind": p.get("kind", ""), "category": p.get("category", ""), "holdout": holdout,
                        "units": len(files), "lines": lines, "syntax_ok": syntax_ok, "clean": clean,
                        "codes": [] if holdout else codes.most_common(8),
                        "messages": [] if holdout else msgs.most_common(6),
                        "features": {} if holdout else dict(feats),
                        "names": [] if holdout else names.most_common(60),
                        "dialect": p.get("dialect", ""),
                        "raw": [] if holdout else [(m, c, where[m]) for m, c in raw.most_common(300)]})
        print(f"{p['name']:30} units {len(files):5}  syntax ok {syntax_ok:5}  clean {clean:5}")
    (CACHE / "analysis.json").write_text(json.dumps(results, indent=1), encoding="utf-8")
    record_history(results)
    write_report(results, all_codes, all_features)


def pct(a, b):
    return f"{100 * a / b:.0f}%" if b else "n/a"


def pct1(a, b):
    return f"{100 * a / b:.1f}%" if b else "n/a"


def metrics(results) -> dict:
    """Headline figures: the core set (application, library, sample) by units,
    its median project, its holdout part, and everything analysed."""
    core = [r for r in results if r.get("category") in CORE and not r.get("dialect")]
    every = [r for r in results if not r.get("dialect")]

    def tot(rs):
        u = sum(r["units"] for r in rs)
        return u, sum(r["syntax_ok"] for r in rs), sum(r["clean"] for r in rs)

    rates = sorted(r["clean"] / r["units"] for r in core if r["units"])
    median = rates[len(rates) // 2] if rates else 0.0
    return {"core": tot(core), "core_projects": len(core), "median_clean": median,
            "holdout": tot([r for r in core if r.get("holdout")]),
            "holdout_projects": sum(1 for r in core if r.get("holdout")),
            "all": tot(every), "all_projects": len(every),
            "by_category": {c: tot([r for r in every if r.get("category") == c])
                            for c in CORE + ("tool-input",)}}


def write_report(results, all_codes, all_features) -> None:
    other = [r for r in results if r.get("dialect")]
    results = [r for r in results if not r.get("dialect")]
    U = sum(r["units"] for r in results)
    L = sum(r["lines"] for r in results)
    m = metrics(results)
    cu, cs, cc = m["core"]
    hu, hs, hc = m["holdout"]
    au, as_, ac = m["all"]
    out = [
        "# Real-world PLC code corpus: what rootplc handles today",
        "",
        f"*Generated {date.today():%Y-%m-%d} by `corpus/corpus.py`. {len(results)} public projects, "
        f"{U} program units (POUs, types, global lists), {L:,} lines of Structured Text.*",
        "",
        "A unit is *syntax OK* when rootplc lexes and parses it; *clean* when it also passes the type",
        "checker with no errors. Units are checked per project, so references to other libraries that",
        "are not in the corpus count as errors. *Clean* is rootplc's own verdict: no vendor compiler has",
        "confirmed that the code is valid, so it measures acceptance, not correctness.",
        "",
        f"**Headline (applications, libraries and samples; {m['core_projects']} projects, {cu} units): "
        f"syntax OK {pct1(cs, cu)} · clean {pct1(cc, cu)} · median project clean {100 * m['median_clean']:.1f}%.**",
        "",
        "| Figure | Projects | Units | Syntax OK | Clean |",
        "|---|---|---|---|---|",
        f"| Headline (core set) | {m['core_projects']} | {cu} | {pct1(cs, cu)} | {pct1(cc, cu)} |",
        f"| Holdout part of the core set (never used to choose fixes) | {m['holdout_projects']} | {hu} | "
        f"{pct1(hs, hu)} | {pct1(hc, hu)} |",
        f"| Everything analysed, tool inputs included | {m['all_projects']} | {au} | {pct1(as_, au)} | {pct1(ac, au)} |",
        "",
        "| Category | Units | Syntax OK | Clean |",
        "|---|---|---|---|",
    ]
    for cat, (u, s, c) in m["by_category"].items():
        out.append(f"| {cat} | {u} | {pct1(s, u)} | {pct1(c, u)} |")
    out += [
        "",
        "Categories (manifest `category`): *application* (a program for a machine or plant), *library*,",
        "*sample* (vendor samples, tutorials, blog and course code), *tool-input* (test inputs and examples",
        "of compilers, parsers, editors, AI tools, benchmarks; not in the headline). A *holdout* project's",
        "errors are never ranked or stored, so its figure shows whether fixes generalise. Projects removed",
        "as empty, duplicated, not Structured Text or too small are listed at the end of the manifest.",
        "",
        "| Project | Category | Licence | Units | Lines | Syntax OK | Clean |",
        "|---|---|---|---|---|---|---|",
    ]
    for r in sorted(results, key=lambda r: -r["units"]):
        cat = r.get("category", "") + (" (holdout)" if r.get("holdout") else "")
        out.append(f"| [{r['name']}]({r['url']}) | {cat} | {r['licence']} | {r['units']} | {r['lines']:,} | "
                   f"{pct(r['syntax_ok'], r['units'])} | {pct(r['clean'], r['units'])} |")
    out += ["", "## What blocks the rest", "", "In the core set without the holdout projects.", "",
            "Units using each construct RootPLC does not support yet:", "",
            "| Construct | Units |", "|---|---|"]
    for k, v in all_features.most_common():
        out.append(f"| {k} | {v} ({pct(v, U)}) |")
    out += ["", "Most frequent error codes:", "", "| Code | Count |", "|---|---|"]
    for k, v in all_codes.most_common(12):
        out.append(f"| {k} | {v} |")
    if other:
        out += ["", "## Other dialects (analysed, not in the totals)", "",
                "| Project | Dialect | Units | Syntax OK | Clean |", "|---|---|---|---|---|"]
        out += [f"| [{r['name']}]({r['url']}) | {r['dialect']} | {r['units']} | "
                f"{pct(r['syntax_ok'], r['units'])} | {pct(r['clean'], r['units'])} |" for r in other]
    skipped = [p for p in projects() if p["format"] in ("binary", "none")]
    if skipped:
        out += ["", "## Listed but not analysed", "", "| Project | Reason |", "|---|---|"]
        out += [f"| [{p['name']}]({p['url']}) | {p.get('note', p['format'])} |" for p in skipped]
    excluded = tomllib.loads((HERE / "manifest.toml").read_text(encoding="utf-8")).get("excluded", [])
    if excluded:
        why = Counter(e["reason"].split(":")[0] if ":" in e["reason"] else "no Structured Text"
                      for e in excluded)
        out += ["", "## Removed from the corpus", "",
                f"{len(excluded)} projects were reviewed and removed (listed with reasons at the end of",
                "manifest.toml, so that discovery does not add them again):", ""]
        out += [f"- {k}: {v}" for k, v in why.most_common()]
    out += ["", "## Licences", "",
            "Only projects marked redistributable (MIT, BSD, Apache, CC0, Unlicense) may be copied into a",
            "published dataset. The others are analysed locally and cited by link.", ""]
    (HERE / "REPORT.md").write_text(with_run_section("\n".join(out)), encoding="utf-8")
    print(f"wrote {HERE / 'REPORT.md'}")


RUN_CYCLES = 500
RUN_BEGIN, RUN_END = "<!-- run smoke test -->", "<!-- /run smoke test -->"


def program_names(files: list[Path]) -> list[str]:
    names = []
    for f in files:
        # not "PROGRAM inst WITH task : prog;" (a program instance in a resource)
        for m in re.finditer(r"^\s*PROGRAM\s+([A-Za-z_]\w*)\b(?!\s*(?:WITH\b|:))", f.read_text(encoding="utf-8"), re.M | re.I):
            names.append(m.group(1))
    return names


def entry_programs(files: list[Path]) -> list[str]:
    """The programs to run: MAIN when there is one, else a program whose name
    contains "main", else every program (at most five)."""
    names = program_names(files)
    for pick in ([n for n in names if n.lower() == "main"], [n for n in names if "main" in n.lower()]):
        if pick:
            return pick[:1]
    return sorted(set(names))[:5]


def clean_subset(exe: str, files: list[Path], extra: list[str], work: Path) -> list[Path]:
    """The largest set of files that checks with no errors: drop the files
    with errors and check again, until nothing more drops. Files are copied
    to `work` (the command line stays short)."""
    keep = list(files)
    for _ in range(12):
        if work.exists():
            shutil.rmtree(work, onexc=_force_remove)
        work.mkdir(parents=True)
        where = {}
        for i, f in enumerate(keep):
            dst = work / f"{i:04d}_{f.name}"
            shutil.copyfile(f, dst)
            where[str(dst.resolve()).lower()] = f
        r = subprocess.run([exe, "check", str(work), *extra, "--json"], capture_output=True, text=True, encoding="utf-8")
        rep = json.loads(r.stdout) if r.stdout.strip().startswith("{") else {}
        bad = {where.get(str(Path(x["file"]).resolve()).lower()) for x in rep.get("diagnostics", [])
               if x.get("severity") == "error"}
        bad.discard(None)
        if not bad:
            return keep
        keep = [f for f in keep if f not in bad]
        if not keep:
            return []
    return []


def run_smoke() -> None:
    """Run each application sub-project for RUN_CYCLES cycles with its inputs at
    their defaults, and record whether it runs, stops with UNSUPPORTED (a
    declared-only library call) or faults. A project with check errors runs
    on its largest error-free part when that still contains the program (then
    everything the program uses is clean). Holdout projects count in the
    totals; their fault details are not stored."""
    exe = rootplc()
    shipped = shipped_libraries(exe)
    analysis = {r["name"]: r for r in json.loads((CACHE / "analysis.json").read_text(encoding="utf-8"))}
    rows = []
    for p in projects():
        if p.get("category") != "application" or p["name"] not in analysis:
            continue
        d = CACHE / p["name"] / "extracted"
        if not d.exists():
            continue
        subdirs = sorted(x for x in d.iterdir() if x.is_dir())
        top = [f for f in d.glob("*.st")]
        targets = [(x, sorted(x.rglob("*.st"))) for x in subdirs if any(x.rglob("*.st"))]
        if top:
            targets.append((d, top) if not subdirs else (d, top))
        for folder, files in targets:
            libs = libraries_for(folder, p["format"], shipped)
            extra = ["--library", ",".join(libs)] if libs else []
            progs = entry_programs(files)
            row = {"project": p["name"], "target": folder.name, "holdout": bool(p.get("holdout")), "runs": [],
                   "units": len(files)}
            if not progs:
                row["outcome"] = "no program"
                rows.append(row)
                continue
            work = CACHE / "_run" / "work"
            keep = clean_subset(exe, files, extra, work)
            row["clean_units"] = len(keep)
            args = [str(work)]
            for prog in progs:
                if not program_names(keep) or prog not in program_names(keep):
                    row["runs"].append({"program": prog, "outcome": "not runnable", "cycles": 0})
                    continue
                try:
                    r = subprocess.run([exe, "run", *args, *extra, "--program", prog, "--cycles", str(RUN_CYCLES), "--json"],
                                       capture_output=True, text=True, encoding="utf-8", timeout=120)
                    rep = json.loads(r.stdout) if r.stdout.strip().startswith("{") else {}
                except subprocess.TimeoutExpired:
                    rep = {"fault": {"kind": "TIMEOUT", "message": "no result in 120 s"}}
                errors = [x for x in rep.get("diagnostics", []) if x.get("severity") == "error"]
                fault = rep.get("fault")
                if errors:
                    outcome = "not runnable"
                elif fault:
                    outcome = "UNSUPPORTED" if fault.get("kind") == "UNSUPPORTED" else "fault"
                elif rep.get("ok"):
                    outcome = "ran"
                else:
                    outcome = "not runnable"
                run = {"program": prog, "outcome": outcome, "cycles": rep.get("cycles", 0)}
                if fault and not p.get("holdout"):
                    run["fault"] = {k: fault.get(k) for k in ("kind", "message", "file", "line")}
                if errors and not p.get("holdout"):
                    run["errors"] = len(errors)
                row["runs"].append(run)
            order = ["fault", "UNSUPPORTED", "not runnable", "ran"]
            row["outcome"] = min((x["outcome"] for x in row["runs"]), key=order.index)
            rows.append(row)
            print(f"run  {p['name'][:40]:40} {folder.name[:30]:30} {row['outcome']}")
    if (CACHE / "_run").exists():
        shutil.rmtree(CACHE / "_run", onexc=_force_remove)
    (CACHE / "run.json").write_text(json.dumps(rows, indent=1), encoding="utf-8")
    report = HERE / "REPORT.md"
    report.write_text(with_run_section(report.read_text(encoding="utf-8")), encoding="utf-8")
    print(f"wrote {report}")


def with_run_section(text: str) -> str:
    """REPORT.md with the run smoke test section from <cache>/run.json."""
    text = re.sub(re.escape(RUN_BEGIN) + r".*?" + re.escape(RUN_END) + r"\n?", "", text, flags=re.S)
    path = CACHE / "run.json"
    if not path.exists():
        return text
    rows = json.loads(path.read_text(encoding="utf-8"))
    out = Counter(r["outcome"] for r in rows)
    kinds = Counter(x["fault"]["kind"] for r in rows for x in r["runs"] if x.get("fault") and x["outcome"] == "fault")
    n = len(rows)
    sec = [RUN_BEGIN, "## Run smoke test (applications)", "",
           f"Each application sub-project is run for {RUN_CYCLES} cycles with its inputs at their defaults",
           "(no I/O simulation): MAIN, else a program named like it, else each program. Files with check",
           "errors are left out (repeatedly, until the rest checks clean); the program runs when it is still",
           "there, so everything it uses checks clean. This shows whether real machine code executes in",
           "rootplc, not whether it behaves correctly.", "",
           "| Outcome | Sub-projects |", "|---|---|"]
    for k in ("ran", "UNSUPPORTED", "fault", "not runnable", "no program"):
        sec.append(f"| {k} | {out.get(k, 0)} ({pct(out.get(k, 0), n)}) |")
    if kinds:
        sec += ["", "Faults by kind (holdout projects not shown): " +
                ", ".join(f"{k} {v}" for k, v in kinds.most_common()) + "."]
    sec += ["", "*ran*: all cycles without a fault; *UNSUPPORTED*: stopped at a library block RootPLC declares",
            "but does not implement; *fault*: a run-time error (index, division, watchdog, ...); *not runnable*:",
            "the program or something it uses has check errors.", RUN_END, ""]
    marker = "## What blocks the rest"
    if marker in text:
        return text.replace(marker, "\n".join(sec) + "\n" + marker, 1)
    return text + "\n" + "\n".join(sec)


def record_history(results) -> None:
    """Append this run's totals to corpus/history.json (public metrics only)."""
    from datetime import datetime
    m = metrics(results)
    U, S, C = m["core"]
    U = U or 1
    # from 4 Nov 2026 the figures are the core set's (see REPORT.md); earlier
    # rows are everything analysed
    row = {"date": datetime.now().strftime("%Y-%m-%d %H:%M"), "units": U,
           "parse": round(100 * S / U), "clean": round(100 * C / U),
           "basis": "core", "median_clean": round(100 * m["median_clean"])}
    path = HERE / "history.json"
    hist = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
    if not hist or (hist[-1]["units"], hist[-1]["parse"], hist[-1]["clean"]) != (row["units"], row["parse"], row["clean"]):
        hist.append(row)
    path.write_text(json.dumps(hist, indent=1), encoding="utf-8")


def dashboard() -> None:
    """Write corpus/dashboard.html (self-contained) from the last analysis."""
    results = json.loads((CACHE / "analysis.json").read_text(encoding="utf-8"))
    m = metrics(results)
    results = [r for r in results if not r.get("dialect") and r.get("category") in CORE]
    feats = Counter()
    for r in results:
        feats.update(r["features"])
    version = subprocess.run([rootplc(), "--version"], capture_output=True, text=True).stdout.strip().replace("rootplc ", "")
    hist_path = HERE / "history.json"
    data = {
        "date": date.today().strftime("%d %b %Y"),
        "listed": len(projects()),
        "rootplc": version,
        "median_clean": round(100 * m["median_clean"]),
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
    elif cmd == "run":
        run_smoke()
    elif cmd == "dashboard":
        dashboard()
    else:
        print(__doc__)
