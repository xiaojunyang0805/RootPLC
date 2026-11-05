//! `rootplc examples`: a small library of verified Structured Text patterns
//! (edge detection, timers, state machines, interlocks, ...). Every example
//! carries TEST blocks and passes `rootplc test`; a unit test enforces that,
//! and another makes sure no example reproduces a benchmark solution.
//!
//! An agent asks for a pattern by keyword and gets code that is known to
//! compile and pass its tests in this toolchain version.

/// The library, compiled in: (id, source).
const LIBRARY: &[(&str, &str)] = &[
    (
        "edge-detect",
        include_str!("../assets/examples/edge-detect.st"),
    ),
    (
        "on-off-delay",
        include_str!("../assets/examples/on-off-delay.st"),
    ),
    (
        "state-machine",
        include_str!("../assets/examples/state-machine.st"),
    ),
    (
        "limit-and-scale",
        include_str!("../assets/examples/limit-and-scale.st"),
    ),
    (
        "counter-preset",
        include_str!("../assets/examples/counter-preset.st"),
    ),
    (
        "interlock-permissive",
        include_str!("../assets/examples/interlock-permissive.st"),
    ),
    (
        "array-loop",
        include_str!("../assets/examples/array-loop.st"),
    ),
    (
        "struct-record",
        include_str!("../assets/examples/struct-record.st"),
    ),
    (
        "testing-pattern",
        include_str!("../assets/examples/testing-pattern.st"),
    ),
    (
        "flip-flops",
        include_str!("../assets/examples/flip-flops.st"),
    ),
    (
        "motion-shuttle",
        include_str!("../assets/examples/motion-shuttle.st"),
    ),
];

/// One verified example.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Example {
    /// Stable identifier, e.g. `edge-detect`.
    pub id: &'static str,
    /// One-line title.
    pub title: String,
    /// Search keywords.
    pub tags: Vec<String>,
    /// What the pattern does and when to use it.
    pub description: String,
    /// Bundled libraries the example needs ([stdlib.compat]), e.g. `RootMotion`.
    pub libraries: Vec<String>,
    /// Complete source, including the header comment and TEST blocks.
    pub source: &'static str,
}

fn header_field(source: &str, key: &str) -> String {
    let header = source
        .strip_prefix("(*")
        .and_then(|s| s.split_once("*)"))
        .map_or("", |(h, _)| h);
    let mut value = String::new();
    let mut inside = false;
    for line in header.lines().map(str::trim) {
        let field = line
            .split_once(':')
            .filter(|(k, _)| ["title", "tags", "description", "libraries"].contains(&k.trim()));
        if let Some((k, v)) = field {
            inside = k.trim() == key;
            if inside {
                value = v.trim().to_string();
            }
        } else if inside && !line.is_empty() {
            value.push(' ');
            value.push_str(line);
        }
    }
    value
}

fn list_field(source: &str, key: &str) -> Vec<String> {
    header_field(source, key)
        .split(',')
        .map(|t| t.trim().to_string())
        .filter(|t| !t.is_empty())
        .collect()
}

fn parse(id: &'static str, source: &'static str) -> Example {
    Example {
        id,
        title: header_field(source, "title"),
        tags: list_field(source, "tags"),
        description: header_field(source, "description"),
        libraries: list_field(source, "libraries"),
        source,
    }
}

/// Every example, in library order.
pub fn all() -> Vec<Example> {
    LIBRARY.iter().map(|&(id, src)| parse(id, src)).collect()
}

/// Example by its id.
pub fn get(id: &str) -> Option<Example> {
    all().into_iter().find(|e| e.id.eq_ignore_ascii_case(id))
}

/// Examples matching every word of `query` best first; an empty query
/// returns the whole library. Tags weigh most, then title, then text.
pub fn search(query: &str) -> Vec<Example> {
    let words: Vec<String> = query
        .split(|c: char| !c.is_alphanumeric() && c != '_')
        .filter(|w| !w.is_empty())
        .map(str::to_lowercase)
        .collect();
    let mut scored: Vec<(u32, Example)> = all()
        .into_iter()
        .filter_map(|e| {
            let tags = e.tags.join(" ").to_lowercase();
            let title = e.title.to_lowercase();
            let text = format!("{} {} {}", e.id, e.description, e.source).to_lowercase();
            let mut score = 0;
            for w in &words {
                let s = 3 * u32::from(tags.contains(w.as_str()))
                    + 2 * u32::from(title.contains(w.as_str()))
                    + u32::from(text.contains(w.as_str()));
                if s == 0 {
                    return None;
                }
                score += s;
            }
            Some((score, e))
        })
        .collect();
    scored.sort_by_key(|a| std::cmp::Reverse(a.0));
    scored.into_iter().map(|(_, e)| e).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::{Path, PathBuf};

    #[test]
    fn every_example_has_a_header_and_passes_its_tests() {
        for e in all() {
            assert!(!e.title.is_empty(), "{}: no title", e.id);
            assert!(!e.tags.is_empty(), "{}: no tags", e.id);
            assert!(!e.description.is_empty(), "{}: no description", e.id);
            let check = crate::check_sources_with(
                vec![(PathBuf::from(e.id), e.source.to_string())],
                &e.libraries,
            )
            .unwrap_or_else(|err| panic!("{}: {err}", e.id));
            assert!(check.ok(), "{}: {:?}", e.id, check.files[0].diagnostics);
            assert_eq!(
                check.count(rootplc_diag::Severity::Warning),
                0,
                "{}: warnings",
                e.id
            );
            let r = crate::test_report(check, None);
            assert!(!r.outcomes.is_empty(), "{}: no TEST block", e.id);
            assert!(r.ok(), "{}: a test fails", e.id);
        }
    }

    #[test]
    fn search_ranks_by_tags() {
        assert_eq!(search("timer")[0].id, "on-off-delay");
        assert_eq!(search("R_TRIG")[0].id, "edge-detect");
        assert_eq!(search("state machine")[0].id, "state-machine");
        assert!(search("no such pattern xyz").is_empty());
        assert_eq!(search("").len(), LIBRARY.len());
        assert_eq!(get("FLIP-FLOPS").map(|e| e.id), Some("flip-flops"));
        assert_eq!(search("motion axis")[0].id, "motion-shuttle");
        assert_eq!(
            get("motion-shuttle").map(|e| e.libraries),
            Some(vec!["RootMotion".to_string()])
        );
    }

    fn pou_names(source: &str) -> Vec<String> {
        let toks: Vec<_> = rootplc_syntax::lex(source)
            .tokens
            .into_iter()
            .filter(|t| !t.kind.is_trivia())
            .collect();
        toks.windows(2)
            .filter(|w| {
                let k = w[0].text(source).to_ascii_uppercase();
                ["PROGRAM", "FUNCTION_BLOCK", "FUNCTION", "TYPE"].contains(&k.as_str())
            })
            .map(|w| w[1].text(source).to_ascii_lowercase())
            .collect()
    }

    fn normalised_lines(source: &str) -> Vec<String> {
        source
            .lines()
            .map(|l| {
                l.split_whitespace()
                    .collect::<Vec<_>>()
                    .join(" ")
                    .to_lowercase()
            })
            .filter(|l| l.len() > 12 && !l.starts_with("end_") && !l.starts_with("var"))
            .collect()
    }

    /// The library must never hand an agent a benchmark solution: no example
    /// declares a name a reference solution declares, and none shares three
    /// consecutive substantive lines with one.
    #[test]
    fn examples_never_contain_bench_solutions() {
        let bench = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../bench/tasks");
        let Ok(tasks) = std::fs::read_dir(&bench) else {
            return; // bench is not shipped with the published crate
        };
        let mut refs = Vec::new();
        for t in tasks.flatten() {
            if let Ok(files) = crate::read_sources(&[t.path().join("reference")]) {
                refs.extend(files.into_iter().map(|(_, s)| s));
            }
        }
        assert!(!refs.is_empty(), "no bench reference solutions found");
        let ref_names: Vec<String> = refs.iter().flat_map(|s| pou_names(s)).collect();
        let ref_windows: Vec<Vec<String>> = refs
            .iter()
            .flat_map(|s| {
                normalised_lines(s)
                    .windows(3)
                    .map(<[_]>::to_vec)
                    .collect::<Vec<_>>()
            })
            .collect();
        for e in all() {
            for n in pou_names(e.source) {
                assert!(
                    !ref_names.contains(&n),
                    "{}: '{n}' is a bench reference name",
                    e.id
                );
            }
            for w in normalised_lines(e.source).windows(3) {
                assert!(
                    !ref_windows.iter().any(|r| r == w),
                    "{}: copies bench lines {w:?}",
                    e.id
                );
            }
        }
    }
}
