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
