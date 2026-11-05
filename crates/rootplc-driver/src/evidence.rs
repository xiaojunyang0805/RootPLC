//! `rootplc evidence`: the evidence pack an engineer reviews and signs off
//! ([tests.evidence]). The pack is deterministic and never signed locally.

use std::path::PathBuf;

use rootplc_diag::{Severity, json_string};

use crate::mutate::{MutationReport, Outcome, mutation_report};
use crate::{TestReport, check_sources_with, explain, sha256, test_report};

/// Format identifier written into every pack.
pub const FORMAT: &str = "rootplc-evidence/0.1";

/// Options for [`evidence`].
#[derive(Debug, Clone)]
pub struct Options {
    /// Compatibility libraries to activate ([stdlib.compat]).
    pub libraries: Vec<String>,
    /// Run mutation testing (default true).
    pub mutate: bool,
    /// Cap on mutants ([tests.mutation]).
    pub mutate_limit: usize,
    /// Required mutation score in percent.
    pub min_score: Option<f64>,
}

impl Default for Options {
    fn default() -> Self {
        Options {
            libraries: Vec::new(),
            mutate: true,
            mutate_limit: crate::mutate::DEFAULT_LIMIT,
            min_score: None,
        }
    }
}

/// One input file of the pack.
#[derive(Debug, Clone)]
pub struct Input {
    /// Path with `/` separators.
    pub path: String,
    /// Size in bytes.
    pub bytes: usize,
    /// SHA-256, lowercase hex.
    pub sha256: String,
}

/// The evidence pack.
#[derive(Debug, Clone)]
pub struct Evidence {
    /// SHA-256 of the rule set compiled into the tool.
    pub spec_sha256: String,
    /// Every source file.
    pub inputs: Vec<Input>,
    /// Compilation and test results.
    pub tests: TestReport,
    /// Mutation testing, when it was run.
    pub mutation: Option<MutationReport>,
    /// Required mutation score in percent, if any.
    pub min_score: Option<f64>,
    /// Why the change is not verified (empty when verified).
    pub reasons: Vec<String>,
}

impl Evidence {
    /// The verdict is `verified`.
    pub fn verified(&self) -> bool {
        self.reasons.is_empty()
    }

    /// No error and no warning ([scope.vendor-forms]).
    pub fn iec_clean(&self) -> bool {
        self.tests.check.ok() && self.tests.check.count(Severity::Warning) == 0
    }
}

/// SHA-256 over the spec chapters and the diagnostic registry compiled in.
pub fn spec_sha256() -> String {
    let mut all = String::new();
    for (path, text) in explain::SPEC {
        all.push_str(path);
        all.push('\n');
        all.push_str(text);
    }
    all.push_str(explain::REGISTRY);
    sha256::hex(all.as_bytes())
}

/// Build the evidence pack for a project ([tests.evidence]).
pub fn evidence(sources: Vec<(PathBuf, String)>, opts: &Options) -> Result<Evidence, String> {
    let inputs = sources
        .iter()
        .map(|(p, s)| Input {
            path: p.display().to_string().replace('\\', "/"),
            bytes: s.len(),
            sha256: sha256::hex(s.as_bytes()),
        })
        .collect();
    let (tests, mutation) = if opts.mutate {
        let m = mutation_report(sources, &opts.libraries, None, opts.mutate_limit)?;
        (m.baseline.clone(), Some(m))
    } else {
        (
            test_report(check_sources_with(sources, &opts.libraries)?, None),
            None,
        )
    };
    let mut reasons = Vec::new();
    if !tests.check.ok() {
        reasons.push(format!(
            "the project does not compile ({} error(s))",
            tests.check.count(Severity::Error)
        ));
    } else if tests.outcomes.is_empty() {
        reasons.push("there are no TEST blocks".to_string());
    } else {
        let failed = tests.outcomes.iter().filter(|o| !o.passed()).count();
        if failed > 0 {
            reasons.push(format!("{failed} test(s) fail"));
        }
    }
    if let (Some(min), true) = (opts.min_score, reasons.is_empty()) {
        match mutation.as_ref().and_then(MutationReport::score) {
            Some(s) if s * 100.0 + 1e-9 >= min => {}
            Some(s) => reasons.push(format!(
                "mutation score {:.0}% is below the required {min}%",
                s * 100.0
            )),
            None => reasons.push(format!(
                "no mutation score to compare with the required {min}%"
            )),
        }
    }
    Ok(Evidence {
        spec_sha256: spec_sha256(),
        inputs,
        tests,
        mutation,
        min_score: opts.min_score,
        reasons,
    })
}

fn opt_num(v: Option<f64>) -> String {
    v.map_or_else(|| "null".to_string(), |x| format!("{x:.4}"))
}

/// The pack as JSON, keys in a fixed order ([tests.evidence]).
pub fn to_json(e: &Evidence) -> String {
    let inputs: Vec<String> = e
        .inputs
        .iter()
        .map(|i| {
            format!(
                "{{\"path\":{},\"bytes\":{},\"sha256\":\"{}\"}}",
                json_string(&i.path),
                i.bytes,
                i.sha256
            )
        })
        .collect();
    let tests: Vec<String> = e
        .tests
        .outcomes
        .iter()
        .map(|o| {
            format!(
                "{{\"name\":{},\"passed\":{}}}",
                json_string(&o.name),
                o.passed()
            )
        })
        .collect();
    let mutation = match &e.mutation {
        None => "null".to_string(),
        Some(m) => {
            let survivors: Vec<String> = m
                .survivors()
                .map(|s| {
                    format!(
                        "{{\"file\":{},\"line\":{},\"column\":{},\"original\":{},\"replacement\":{}}}",
                        json_string(&s.path.display().to_string().replace('\\', "/")),
                        s.line,
                        s.column,
                        json_string(&s.original),
                        json_string(&s.replacement)
                    )
                })
                .collect();
            let not_viable = m
                .mutants
                .iter()
                .filter(|(_, o)| *o == Outcome::NotViable)
                .count();
            format!(
                "{{\"score\":{},\"killed\":{},\"viable\":{},\"not_viable\":{not_viable},\"candidates\":{},\"run\":{},\"error\":{},\"survivors\":[{}]}}",
                opt_num(m.score()),
                m.killed(),
                m.viable(),
                m.candidates,
                m.mutants.len(),
                m.error
                    .as_deref()
                    .map_or_else(|| "null".to_string(), json_string),
                survivors.join(",")
            )
        }
    };
    let reasons: Vec<String> = e.reasons.iter().map(|r| json_string(r)).collect();
    let c = &e.tests.check;
    format!(
        "{{\"format\":\"{FORMAT}\",\
\"tool\":{{\"name\":\"rootplc\",\"version\":\"{}\",\"spec_sha256\":\"{}\"}},\
\"inputs\":[{}],\
\"check\":{{\"compiled\":{},\"errors\":{},\"warnings\":{},\"iec_clean\":{}}},\
\"tests\":{{\"passed\":{},\"failed\":{},\"items\":[{}]}},\
\"mutation\":{mutation},\
\"min_score\":{},\
\"verdict\":\"{}\",\"reasons\":[{}],\
\"signature\":null}}",
        env!("CARGO_PKG_VERSION"),
        e.spec_sha256,
        inputs.join(","),
        c.ok(),
        c.count(Severity::Error),
        c.count(Severity::Warning),
        e.iec_clean(),
        e.tests.outcomes.iter().filter(|o| o.passed()).count(),
        e.tests.outcomes.iter().filter(|o| !o.passed()).count(),
        tests.join(","),
        e.min_score
            .map_or_else(|| "null".to_string(), |m| format!("{m}")),
        if e.verified() {
            "verified"
        } else {
            "not verified"
        },
        reasons.join(",")
    )
}

/// A readable summary of the pack ([tests.evidence]).
pub fn to_markdown(e: &Evidence) -> String {
    let mut s = String::from("# Evidence pack\n\n");
    if e.verified() {
        s.push_str("**Verdict: verified**\n\n");
    } else {
        s.push_str(&format!(
            "**Verdict: not verified**: {}\n\n",
            e.reasons.join("; ")
        ));
    }
    s.push_str(&format!(
        "Tool: rootplc {} · rule set SHA-256 `{}` · format {FORMAT} · unsigned (local pack)\n\n",
        env!("CARGO_PKG_VERSION"),
        &e.spec_sha256[..16]
    ));
    s.push_str("## Inputs\n\n| File | Bytes | SHA-256 |\n|---|---:|---|\n");
    for i in &e.inputs {
        s.push_str(&format!("| {} | {} | `{}` |\n", i.path, i.bytes, i.sha256));
    }
    let c = &e.tests.check;
    s.push_str(&format!(
        "\n## Check\n\nCompiles: {} · errors: {} · warnings: {} · IEC clean: {}\n",
        if c.ok() { "yes" } else { "no" },
        c.count(Severity::Error),
        c.count(Severity::Warning),
        if e.iec_clean() { "yes" } else { "no" }
    ));
    let passed = e.tests.outcomes.iter().filter(|o| o.passed()).count();
    s.push_str(&format!(
        "\n## Tests\n\n{passed} of {} passed\n\n",
        e.tests.outcomes.len()
    ));
    for o in &e.tests.outcomes {
        s.push_str(&format!(
            "- {} {}\n",
            if o.passed() { "PASS" } else { "FAIL" },
            o.name
        ));
    }
    s.push_str("\n## Mutation testing\n\n");
    match &e.mutation {
        None => s.push_str("Not run (`--no-mutate`).\n"),
        Some(m) => match (&m.error, m.score()) {
            (Some(err), _) => s.push_str(&format!("Not run: {err}.\n")),
            (None, None) => s.push_str("No viable mutants.\n"),
            (None, Some(score)) => {
                s.push_str(&format!(
                    "Score {:.0}%: {} of {} viable mutants killed.\n",
                    score * 100.0,
                    m.killed(),
                    m.viable()
                ));
                let survivors: Vec<_> = m.survivors().collect();
                if !survivors.is_empty() {
                    s.push_str("\nSurviving changes (add a test for each):\n\n");
                    for v in survivors {
                        s.push_str(&format!(
                            "- {}:{}:{}: `{}` → `{}`\n",
                            v.path.display().to_string().replace('\\', "/"),
                            v.line,
                            v.column,
                            v.original,
                            if v.replacement.is_empty() {
                                "(removed)"
                            } else {
                                &v.replacement
                            }
                        ));
                    }
                }
            }
        },
    }
    s
}

#[cfg(test)]
mod tests {
    use super::*;

    fn latch(test: &str) -> Vec<(PathBuf, String)> {
        vec![
            (
                PathBuf::from("src/latch.st"),
                "FUNCTION_BLOCK FB_Latch\nVAR_INPUT start : BOOL; stop : BOOL; END_VAR\n\
                 VAR_OUTPUT running : BOOL; END_VAR\nrunning := (start OR running) AND NOT stop;\n\
                 END_FUNCTION_BLOCK\n"
                    .to_string(),
            ),
            (PathBuf::from("tests/latch_test.st"), test.to_string()),
        ]
    }

    const STRONG: &str = "TEST latch\nVAR l : FB_Latch; END_VAR\n\
        l(start := TRUE, stop := FALSE); ASSERT_TRUE(l.running);\n\
        l(start := FALSE, stop := FALSE); ASSERT_TRUE(l.running);\n\
        l(start := TRUE, stop := TRUE); ASSERT_FALSE(l.running);\nEND_TEST\n";

    #[test]
    fn verified_pack_is_deterministic_and_unsigned() {
        let a = to_json(&evidence(latch(STRONG), &Options::default()).expect("pack"));
        let b = to_json(&evidence(latch(STRONG), &Options::default()).expect("pack"));
        assert_eq!(a, b);
        assert!(a.contains("\"verdict\":\"verified\""), "{a}");
        assert!(a.contains("\"signature\":null"));
        assert!(a.contains("\"iec_clean\":true"));
        assert!(a.contains("\"score\":1.0000"));
        assert!(a.contains("\"path\":\"src/latch.st\""));
    }

    #[test]
    fn weak_tests_fail_a_min_score() {
        let weak = "TEST sets\nVAR l : FB_Latch; END_VAR\nl(start := TRUE, stop := FALSE); ASSERT_TRUE(l.running);\nEND_TEST\n";
        let opts = Options {
            min_score: Some(90.0),
            ..Options::default()
        };
        let e = evidence(latch(weak), &opts).expect("pack");
        assert!(!e.verified());
        assert!(e.reasons[0].contains("below the required"));
        assert!(to_markdown(&e).contains("Surviving changes"));
    }

    #[test]
    fn no_tests_is_not_verified() {
        let e = evidence(latch(""), &Options::default()).expect("pack");
        assert_eq!(e.reasons, vec!["there are no TEST blocks".to_string()]);
    }
}
