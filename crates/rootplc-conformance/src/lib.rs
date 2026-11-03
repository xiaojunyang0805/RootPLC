//! Conformance suite loader and consistency checks between `spec/`,
//! `spec/diagnostics.toml` and `conformance/cases/`.
//!
//! Roadmap phase: 0. Later this crate also executes the cases against the
//! compiler and VM. See `conformance/README.md`.

use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};

/// Expected outcome of a case.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Expect {
    /// Compiles without errors or warnings.
    Ok,
    /// Fails with these error codes.
    Error(Vec<String>),
    /// Compiles with these warnings.
    Warning(Vec<String>),
}

/// One conformance case.
#[derive(Debug, Clone)]
pub struct Case {
    /// Path of the `.st` file.
    pub path: PathBuf,
    /// Rule IDs cited by `spec:`.
    pub spec: Vec<String>,
    /// Expected outcome.
    pub expect: Expect,
    /// Optional `run:` line.
    pub run: Option<String>,
    /// `assert:` lines.
    pub asserts: Vec<String>,
    /// Full source text.
    pub source: String,
}

/// A diagnostic code entry from `spec/diagnostics.toml`.
#[derive(Debug, Clone, Default)]
pub struct CodeEntry {
    /// `RPnnnn`.
    pub id: String,
    /// `error`, `warning` or `note`.
    pub severity: String,
    /// Rule ID the code belongs to.
    pub spec: String,
    /// Compiler phase that reports it: `lex`, `parse` or `sema`.
    pub stage: String,
}

/// Repository root, derived from this crate's location.
pub fn repo_root() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}

/// Parse the header comment of a case.
pub fn parse_case(path: &Path, source: &str) -> Result<Case, String> {
    let err = |m: &str| format!("{}: {m}", path.display());
    let body = source.trim_start_matches('\u{feff}');
    let start = body.find("(*").ok_or_else(|| err("no header comment"))?;
    if !body[..start].trim().is_empty() {
        return Err(err("header comment must come first"));
    }
    let end = body[start..]
        .find("*)")
        .ok_or_else(|| err("unterminated header"))?
        + start;
    let header = &body[start + 2..end];

    let (mut spec, mut expect, mut run, mut asserts) = (Vec::new(), None, None, Vec::new());
    for line in header.lines().map(str::trim).filter(|l| !l.is_empty()) {
        let (key, value) = line
            .split_once(':')
            .ok_or_else(|| err(&format!("bad header line '{line}'")))?;
        let value = value.trim();
        match key.trim() {
            "spec" => {
                for tok in value.split_whitespace() {
                    let id = tok
                        .strip_prefix('[')
                        .and_then(|t| t.strip_suffix(']'))
                        .ok_or_else(|| err(&format!("spec id must be [bracketed]: {tok}")))?;
                    spec.push(id.to_string());
                }
            }
            "expect" => {
                let mut words = value.split_whitespace();
                let kind = words.next().unwrap_or("");
                let codes: Vec<String> = words.map(str::to_string).collect();
                expect = Some(match kind {
                    "ok" if codes.is_empty() => Expect::Ok,
                    "error" if !codes.is_empty() => Expect::Error(codes),
                    "warning" if !codes.is_empty() => Expect::Warning(codes),
                    _ => return Err(err(&format!("bad expect '{value}'"))),
                });
            }
            "run" => run = Some(value.to_string()),
            "assert" => asserts.push(value.to_string()),
            other => return Err(err(&format!("unknown header key '{other}'"))),
        }
    }
    if spec.is_empty() {
        return Err(err("missing spec:"));
    }
    if !asserts.is_empty() && run.is_none() {
        return Err(err("assert: needs run:"));
    }
    Ok(Case {
        path: path.to_path_buf(),
        spec,
        expect: expect.ok_or_else(|| err("missing expect:"))?,
        run,
        asserts,
        source: source.to_string(),
    })
}

fn collect_files(dir: &Path, ext: &str, out: &mut Vec<PathBuf>) -> std::io::Result<()> {
    for entry in fs::read_dir(dir)? {
        let path = entry?.path();
        if path.is_dir() {
            collect_files(&path, ext, out)?;
        } else if path.extension().is_some_and(|e| e == ext) {
            out.push(path);
        }
    }
    out.sort();
    Ok(())
}

/// Load and parse every case under `conformance/cases`.
pub fn load_cases(root: &Path) -> Result<Vec<Case>, String> {
    let mut files = Vec::new();
    collect_files(&root.join("conformance/cases"), "st", &mut files).map_err(|e| e.to_string())?;
    files
        .iter()
        .map(|p| {
            let src = fs::read_to_string(p).map_err(|e| format!("{}: {e}", p.display()))?;
            parse_case(p, &src)
        })
        .collect()
}

/// Rule IDs defined in the spec, written as `**[a.b.c]**`, mapped to their file.
pub fn spec_rule_ids(root: &Path) -> Result<BTreeMap<String, PathBuf>, String> {
    let mut files = Vec::new();
    collect_files(&root.join("spec"), "md", &mut files).map_err(|e| e.to_string())?;
    let mut ids = BTreeMap::new();
    for f in files {
        let text = fs::read_to_string(&f).map_err(|e| e.to_string())?;
        let mut rest = text.as_str();
        while let Some(i) = rest.find("**[") {
            rest = &rest[i + 3..];
            if let Some(j) = rest.find("]**") {
                let id = &rest[..j];
                if let Some(prev) = ids.insert(id.to_string(), f.clone()) {
                    return Err(format!("rule [{id}] defined twice ({})", prev.display()));
                }
                rest = &rest[j + 3..];
            }
        }
    }
    Ok(ids)
}

/// Parse `spec/diagnostics.toml` (the small subset of TOML it uses).
pub fn load_registry(root: &Path) -> Result<Vec<CodeEntry>, String> {
    let text = fs::read_to_string(root.join("spec/diagnostics.toml")).map_err(|e| e.to_string())?;
    let mut entries: Vec<CodeEntry> = Vec::new();
    for line in text.lines().map(str::trim) {
        if line == "[[code]]" {
            entries.push(CodeEntry::default());
        } else if let (Some((k, v)), Some(e)) = (line.split_once('='), entries.last_mut()) {
            if line.starts_with('#') {
                continue;
            }
            let v = v.trim().trim_matches('"').to_string();
            match k.trim() {
                "id" => e.id = v,
                "severity" => e.severity = v,
                "spec" => e.spec = v,
                "stage" => e.stage = v,
                _ => {}
            }
        }
    }
    Ok(entries)
}

/// Run every consistency rule from `conformance/README.md`; return all problems found.
pub fn check_consistency(root: &Path) -> Result<Vec<String>, String> {
    let cases = load_cases(root)?;
    let rules = spec_rule_ids(root)?;
    let registry = load_registry(root)?;
    let mut problems = Vec::new();

    let mut codes: BTreeMap<&str, &CodeEntry> = BTreeMap::new();
    for e in &registry {
        let valid = e.id.len() == 6
            && e.id.starts_with("RP")
            && e.id[2..].chars().all(|c| c.is_ascii_digit());
        if !valid {
            problems.push(format!("registry: bad code id '{}'", e.id));
        }
        if !matches!(e.stage.as_str(), "lex" | "parse" | "sema") {
            problems.push(format!("registry: {} has bad stage '{}'", e.id, e.stage));
        }
        if !matches!(e.severity.as_str(), "error" | "warning" | "note") {
            problems.push(format!(
                "registry: {} has bad severity '{}'",
                e.id, e.severity
            ));
        }
        if !rules.contains_key(&e.spec) {
            problems.push(format!(
                "registry: {} cites unknown rule [{}]",
                e.id, e.spec
            ));
        }
        if codes.insert(&e.id, e).is_some() {
            problems.push(format!("registry: {} defined twice", e.id));
        }
    }

    let mut cited_rules = BTreeSet::new();
    let mut expected_codes = BTreeSet::new();
    for c in &cases {
        let name = c
            .path
            .strip_prefix(root)
            .unwrap_or(&c.path)
            .display()
            .to_string();
        for id in &c.spec {
            if !rules.contains_key(id) {
                problems.push(format!("{name}: unknown rule [{id}]"));
            }
            cited_rules.insert(id.clone());
        }
        let (severity, list) = match &c.expect {
            Expect::Ok => continue,
            Expect::Error(l) => ("error", l),
            Expect::Warning(l) => ("warning", l),
        };
        for code in list {
            expected_codes.insert(code.clone());
            match codes.get(code.as_str()) {
                None => problems.push(format!("{name}: unknown code {code}")),
                Some(e) if e.severity != severity => problems.push(format!(
                    "{name}: expects {severity} {code}, registry says {}",
                    e.severity
                )),
                Some(_) => {}
            }
        }
    }

    for id in rules.keys().filter(|id| !cited_rules.contains(*id)) {
        problems.push(format!("rule [{id}] has no conformance case"));
    }
    for id in codes.keys().filter(|id| !expected_codes.contains(**id)) {
        problems.push(format!("code {id} is not expected by any case"));
    }
    Ok(problems)
}

/// The code table compiled into `rootplc-diag` must equal the registry.
pub fn check_code_table(root: &Path) -> Result<Vec<String>, String> {
    let registry: BTreeSet<(String, String)> = load_registry(root)?
        .into_iter()
        .map(|e| (e.id, e.severity))
        .collect();
    let table: BTreeSet<(String, String)> = rootplc_diag::codes::ALL
        .iter()
        .map(|(c, s)| (c.to_string(), s.as_str().to_string()))
        .collect();
    let mut problems = Vec::new();
    for x in registry.difference(&table) {
        problems.push(format!(
            "{} ({}) is in diagnostics.toml but not in rootplc-diag",
            x.0, x.1
        ));
    }
    for x in table.difference(&registry) {
        problems.push(format!(
            "{} ({}) is in rootplc-diag but not in diagnostics.toml",
            x.0, x.1
        ));
    }
    Ok(problems)
}

/// Run every case through the lexer. For each case, the set of lexer codes
/// must equal the expected codes whose registry stage is `lex`, and the
/// tokens must reproduce the source exactly (lossless lexing).
pub fn run_lex_stage(root: &Path) -> Result<Vec<String>, String> {
    let lex_codes: BTreeSet<String> = load_registry(root)?
        .into_iter()
        .filter(|e| e.stage == "lex")
        .map(|e| e.id)
        .collect();
    let mut problems = Vec::new();
    for c in load_cases(root)? {
        let name = c
            .path
            .strip_prefix(root)
            .unwrap_or(&c.path)
            .display()
            .to_string();
        let r = rootplc_syntax::lex(&c.source);
        let joined: String = r.tokens.iter().map(|t| t.text(&c.source)).collect();
        if joined != c.source {
            problems.push(format!("{name}: tokens do not reproduce the source"));
        }
        let got: BTreeSet<String> = r.diagnostics.iter().map(|d| d.code.to_string()).collect();
        let want: BTreeSet<String> = match &c.expect {
            Expect::Ok => BTreeSet::new(),
            Expect::Error(l) | Expect::Warning(l) => l
                .iter()
                .filter(|x| lex_codes.contains(*x))
                .cloned()
                .collect(),
        };
        if got != want {
            problems.push(format!("{name}: lexer reported {got:?}, expected {want:?}"));
        }
    }
    Ok(problems)
}

/// Run every case through the parser. The tree must reproduce the source
/// exactly (lossless). For cases without lexical errors, the set of parser
/// codes must equal the expected codes whose registry stage is `parse`; cases
/// with lexical errors are not graded here, to avoid cascades.
pub fn run_parse_stage(root: &Path) -> Result<Vec<String>, String> {
    let parse_codes: BTreeSet<String> = load_registry(root)?
        .into_iter()
        .filter(|e| e.stage == "parse")
        .map(|e| e.id)
        .collect();
    let mut problems = Vec::new();
    for c in load_cases(root)? {
        let name = c
            .path
            .strip_prefix(root)
            .unwrap_or(&c.path)
            .display()
            .to_string();
        let p = rootplc_syntax::parse(&c.source);
        if p.tree.text(&p.tokens, &c.source) != c.source {
            problems.push(format!("{name}: syntax tree does not reproduce the source"));
        }
        let lex_error = p
            .lex_diagnostics
            .iter()
            .any(|d| d.severity == rootplc_diag::Severity::Error);
        if lex_error {
            continue;
        }
        let got: BTreeSet<String> = p.diagnostics.iter().map(|d| d.code.to_string()).collect();
        let want: BTreeSet<String> = match &c.expect {
            Expect::Ok => BTreeSet::new(),
            Expect::Error(l) | Expect::Warning(l) => l
                .iter()
                .filter(|x| parse_codes.contains(*x))
                .cloned()
                .collect(),
        };
        if got != want {
            let detail: Vec<String> = p
                .diagnostics
                .iter()
                .map(|d| format!("{} @{}: {}", d.code, d.span.start, d.message))
                .collect();
            problems.push(format!(
                "{name}: parser reported {got:?}, expected {want:?} [{}]",
                detail.join("; ")
            ));
        }
    }
    Ok(problems)
}

/// Run every case through the checker. Graded only for cases that lex and
/// parse without errors: the set of checker codes must equal the expected
/// codes whose registry stage is `sema`.
pub fn run_sema_stage(root: &Path) -> Result<Vec<String>, String> {
    let sema_codes: BTreeSet<String> = load_registry(root)?
        .into_iter()
        .filter(|e| e.stage == "sema")
        .map(|e| e.id)
        .collect();
    let mut problems = Vec::new();
    for c in load_cases(root)? {
        let name = c
            .path
            .strip_prefix(root)
            .unwrap_or(&c.path)
            .display()
            .to_string();
        let p = rootplc_syntax::parse(&c.source);
        let syntax_error = p
            .lex_diagnostics
            .iter()
            .chain(&p.diagnostics)
            .any(|d| d.severity == rootplc_diag::Severity::Error);
        if syntax_error {
            continue;
        }
        let diags = rootplc_sema::check(&p, &c.source);
        let got: BTreeSet<String> = diags.iter().map(|d| d.code.to_string()).collect();
        let want: BTreeSet<String> = match &c.expect {
            Expect::Ok => BTreeSet::new(),
            Expect::Error(l) | Expect::Warning(l) => l
                .iter()
                .filter(|x| sema_codes.contains(*x))
                .cloned()
                .collect(),
        };
        if got != want {
            let detail: Vec<String> = diags
                .iter()
                .map(|d| format!("{} @{}: {}", d.code, d.span.start, d.message))
                .collect();
            problems.push(format!(
                "{name}: checker reported {got:?}, expected {want:?} [{}]",
                detail.join("; ")
            ));
        }
    }
    Ok(problems)
}

/// Rewrite an `assert:` expression so that variable names refer to the
/// instance under test: `a[2] = 3` becomes `conf_uut.a[2] = 3`.
fn qualify_assert(expr: &str) -> String {
    let lexed = rootplc_syntax::lex(expr);
    let mut out = String::new();
    let mut prev_dot = false;
    for t in &lexed.tokens {
        let text = t.text(expr);
        if t.kind == rootplc_syntax::TokenKind::Ident && !prev_dot {
            out.push_str("conf_uut.");
        }
        out.push_str(text);
        if !t.kind.is_trivia() {
            prev_dot = t.kind == rootplc_syntax::TokenKind::Dot;
        }
    }
    out
}

/// Compile one source text and run its TEST blocks. Returns problems.
fn compile_and_test(name: &str, source: &str) -> Vec<String> {
    let p = rootplc_syntax::parse(source);
    let syntax: Vec<String> = p
        .lex_diagnostics
        .iter()
        .chain(&p.diagnostics)
        .filter(|d| d.severity == rootplc_diag::Severity::Error)
        .map(|d| format!("{} {}", d.code, d.message))
        .collect();
    if !syntax.is_empty() {
        return vec![format!("{name}: does not parse: {}", syntax.join("; "))];
    }
    let a = rootplc_sema::analyze(&[(&p, source)]);
    if !a.ok() {
        let errs: Vec<String> = a
            .diagnostics
            .iter()
            .flatten()
            .map(|d| format!("{} {}", d.code, d.message))
            .collect();
        return vec![format!("{name}: does not check: {}", errs.join("; "))];
    }
    rootplc_testing::run_tests(&a.program, None)
        .into_iter()
        .filter(|o| !o.passed())
        .map(|o| {
            let mut why: Vec<String> = o.failures.iter().map(|f| f.message.clone()).collect();
            if let Some(f) = &o.fault {
                why.push(format!("fault {}: {}", f.kind.name(), f.message));
            }
            format!("{name}: test {} failed: {}", o.name, why.join("; "))
        })
        .collect()
}

/// Execute the cases: every TEST block of a case that compiles without errors
/// must pass, and every `run:` / `assert:` pair must hold. `run: P cycles=N`
/// runs program `P` N times, then each assertion is evaluated against the
/// program's variables ([tests.whitebox]).
pub fn run_exec_stage(root: &Path) -> Result<Vec<String>, String> {
    let mut problems = Vec::new();
    for c in load_cases(root)? {
        if matches!(c.expect, Expect::Error(_)) {
            continue;
        }
        let name = c
            .path
            .strip_prefix(root)
            .unwrap_or(&c.path)
            .display()
            .to_string();
        let mut source = c.source.clone();
        if let Some(run) = &c.run {
            let mut words = run.split_whitespace();
            let prog = words.next().unwrap_or("");
            let cycles: usize = words
                .find_map(|w| w.strip_prefix("cycles="))
                .and_then(|n| n.parse().ok())
                .unwrap_or(1);
            source.push_str(&format!(
                "
TEST conformance_run
VAR
    conf_uut : {prog};
END_VAR
"
            ));
            for _ in 0..cycles {
                source.push_str(
                    "conf_uut();
",
                );
            }
            for a in &c.asserts {
                source.push_str(&format!(
                    "ASSERT_TRUE({});
",
                    qualify_assert(a)
                ));
            }
            source.push_str(
                "END_TEST
",
            );
        }
        problems.extend(compile_and_test(&name, &source));
    }
    Ok(problems)
}

/// The TEST blocks of every example project must pass.
pub fn test_examples(root: &Path) -> Result<Vec<String>, String> {
    let mut problems = Vec::new();
    for entry in fs::read_dir(root.join("examples")).map_err(|e| e.to_string())? {
        let dir = entry.map_err(|e| e.to_string())?.path();
        if !dir.is_dir() {
            continue;
        }
        let mut files = Vec::new();
        collect_files(&dir, "st", &mut files).map_err(|e| e.to_string())?;
        let sources = files
            .iter()
            .map(|f| fs::read_to_string(f).map_err(|e| e.to_string()))
            .collect::<Result<Vec<_>, _>>()?;
        let parses: Vec<_> = sources.iter().map(|s| rootplc_syntax::parse(s)).collect();
        let input: Vec<_> = parses
            .iter()
            .zip(&sources)
            .map(|(p, s)| (p, s.as_str()))
            .collect();
        let a = rootplc_sema::analyze(&input);
        if !a.ok() {
            continue; // reported by check_examples
        }
        for o in rootplc_testing::run_tests(&a.program, None) {
            if !o.passed() {
                let mut why: Vec<String> = o.failures.iter().map(|f| f.message.clone()).collect();
                if let Some(f) = &o.fault {
                    why.push(format!("fault {}: {}", f.kind.name(), f.message));
                }
                problems.push(format!(
                    "{}: test {} failed: {}",
                    dir.display(),
                    o.name,
                    why.join("; ")
                ));
            }
        }
    }
    Ok(problems)
}

/// Every project under `examples/` (one per folder) and the stdlib must check
/// without diagnostics. The files of a project are checked together.
pub fn check_examples(root: &Path) -> Result<Vec<String>, String> {
    let mut projects = vec![root.join("crates/rootplc-stdlib/st")];
    for entry in fs::read_dir(root.join("examples")).map_err(|e| e.to_string())? {
        let path = entry.map_err(|e| e.to_string())?.path();
        if path.is_dir() {
            projects.push(path);
        }
    }
    let mut problems = Vec::new();
    for dir in projects {
        let mut files = Vec::new();
        collect_files(&dir, "st", &mut files).map_err(|e| e.to_string())?;
        let sources = files
            .iter()
            .map(|f| fs::read_to_string(f).map_err(|e| e.to_string()))
            .collect::<Result<Vec<_>, _>>()?;
        let parses: Vec<_> = sources.iter().map(|s| rootplc_syntax::parse(s)).collect();
        if parses
            .iter()
            .any(|p| !p.lex_diagnostics.is_empty() || !p.diagnostics.is_empty())
        {
            continue; // reported by lex_examples / parse_examples
        }
        let input: Vec<_> = parses
            .iter()
            .zip(&sources)
            .map(|(p, s)| (p, s.as_str()))
            .collect();
        for (f, diags) in files.iter().zip(rootplc_sema::check_project(&input)) {
            for d in diags {
                problems.push(format!(
                    "{}: {} @{}: {}",
                    f.display(),
                    d.code,
                    d.span.start,
                    d.message
                ));
            }
        }
    }
    Ok(problems)
}

/// Every `.st` file under `examples/` and the stdlib must parse without diagnostics.
pub fn parse_examples(root: &Path) -> Result<Vec<String>, String> {
    let mut files = Vec::new();
    for dir in ["examples", "crates/rootplc-stdlib/st"] {
        collect_files(&root.join(dir), "st", &mut files).map_err(|e| e.to_string())?;
    }
    let mut problems = Vec::new();
    for f in files {
        let src = fs::read_to_string(&f).map_err(|e| e.to_string())?;
        let p = rootplc_syntax::parse(&src);
        if p.tree.text(&p.tokens, &src) != src {
            problems.push(format!(
                "{}: syntax tree does not reproduce the source",
                f.display()
            ));
        }
        for d in p.diagnostics {
            problems.push(format!(
                "{}: {} @{}: {}",
                f.display(),
                d.code,
                d.span.start,
                d.message
            ));
        }
    }
    Ok(problems)
}

/// Every `.st` file under `examples/` and the stdlib must lex without diagnostics.
pub fn lex_examples(root: &Path) -> Result<Vec<String>, String> {
    let mut files = Vec::new();
    for dir in ["examples", "crates/rootplc-stdlib/st"] {
        collect_files(&root.join(dir), "st", &mut files).map_err(|e| e.to_string())?;
    }
    let mut problems = Vec::new();
    for f in files {
        let src = fs::read_to_string(&f).map_err(|e| e.to_string())?;
        for d in rootplc_syntax::lex(&src).diagnostics {
            problems.push(format!("{}: {} {}", f.display(), d.code, d.message));
        }
    }
    Ok(problems)
}

/// The spec files and the AGENTS.md template embedded in `rootplc-driver`
/// (so that `cargo publish` can package them) must equal the originals.
pub fn check_embedded_assets(root: &Path) -> Result<Vec<String>, String> {
    let assets = root.join("crates/rootplc-driver/assets");
    let mut pairs: Vec<(PathBuf, PathBuf)> = vec![(
        root.join("agent/templates/AGENTS.md"),
        assets.join("AGENTS.md"),
    )];
    for entry in fs::read_dir(assets.join("spec")).map_err(|e| e.to_string())? {
        let copy = entry.map_err(|e| e.to_string())?.path();
        let name = copy
            .file_name()
            .map(|n| n.to_os_string())
            .unwrap_or_default();
        pairs.push((root.join("spec").join(name), copy));
    }
    let plugin = root.join("agent/plugins/claude-code");
    pairs.push((
        root.join("agent/mcp/claude-code.json"),
        plugin.join(".mcp.json"),
    ));
    for skill in ["rootplc-st", "rootplc-migrate"] {
        pairs.push((
            root.join("agent/skills").join(skill).join("SKILL.md"),
            plugin.join("skills").join(skill).join("SKILL.md"),
        ));
    }
    let mut problems = Vec::new();
    for (orig, copy) in pairs {
        let a = fs::read(&orig).map_err(|e| format!("{}: {e}", orig.display()))?;
        let b = fs::read(&copy).map_err(|e| format!("{}: {e}", copy.display()))?;
        if a != b {
            problems.push(format!(
                "{} differs from {}; copy the original over it",
                copy.display(),
                orig.display()
            ));
        }
    }
    Ok(problems)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_header() {
        let src = "(* spec: [a.b] [c.d]\n   expect: error RP0001\n *)\nPROGRAM P END_PROGRAM\n";
        let c = parse_case(Path::new("x.st"), src).expect("parses");
        assert_eq!(c.spec, ["a.b", "c.d"]);
        assert_eq!(c.expect, Expect::Error(vec!["RP0001".into()]));
    }

    #[test]
    fn rejects_assert_without_run() {
        let src = "(* spec: [a.b]\n expect: ok\n assert: x = 1 *)\n";
        assert!(parse_case(Path::new("x.st"), src).is_err());
    }
}
