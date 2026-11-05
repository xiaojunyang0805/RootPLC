//! Spec, diagnostic registry, code table, cases, lexer, parser, checker and VM must agree.

use rootplc_conformance as rc;

fn assert_clean(what: &str, problems: Result<Vec<String>, String>) {
    let problems = problems.expect("suite loads");
    assert!(
        problems.is_empty(),
        "{what}: {} problem(s):\n{}",
        problems.len(),
        problems.join("\n")
    );
}

#[test]
fn spec_registry_and_cases_are_consistent() {
    assert_clean("consistency", rc::check_consistency(&rc::repo_root()));
}

#[test]
fn code_table_matches_registry() {
    assert_clean("code table", rc::check_code_table(&rc::repo_root()));
}

#[test]
fn lexer_meets_lex_stage_expectations() {
    assert_clean("lex stage", rc::run_lex_stage(&rc::repo_root()));
}

#[test]
fn examples_and_stdlib_lex_cleanly() {
    assert_clean("examples", rc::lex_examples(&rc::repo_root()));
}

#[test]
fn parser_meets_parse_stage_expectations() {
    assert_clean("parse stage", rc::run_parse_stage(&rc::repo_root()));
}

#[test]
fn examples_and_stdlib_parse_cleanly() {
    assert_clean("examples parse", rc::parse_examples(&rc::repo_root()));
}

#[test]
fn checker_meets_sema_stage_expectations() {
    assert_clean("sema stage", rc::run_sema_stage(&rc::repo_root()));
}

#[test]
fn examples_and_stdlib_check_cleanly() {
    assert_clean("examples check", rc::check_examples(&rc::repo_root()));
}

#[test]
fn cases_execute_and_assertions_hold() {
    assert_clean("exec stage", rc::run_exec_stage(&rc::repo_root()));
}

/// Cases with a `mutate:` line: mutation testing gives exactly the stated
/// counts ([tests.mutation]).
#[test]
fn mutation_counts_match() {
    let root = rc::repo_root();
    let mut problems = Vec::new();
    let cases = rc::load_cases(&root).unwrap_or_default();
    assert!(
        cases.iter().any(|c| c.mutate.is_some()),
        "no mutate: case found"
    );
    for c in cases {
        let Some(want) = &c.mutate else { continue };
        let r = rootplc_driver::mutate::mutation_report(
            vec![(c.path.clone(), c.source.clone())],
            &c.libraries,
            None,
            rootplc_driver::mutate::DEFAULT_LIMIT,
        );
        let got = match r {
            Ok(r) => match &r.error {
                Some(e) => format!("error: {e}"),
                None => format!("killed={} viable={}", r.killed(), r.viable()),
            },
            Err(e) => format!("error: {e}"),
        };
        let matches = if let Some(w) = want.strip_prefix("error") {
            got.starts_with("error") && got.contains(w.trim())
        } else {
            &got == want
        };
        if !matches {
            problems.push(format!(
                "{}: mutate: want '{want}', got '{got}'",
                c.path.display()
            ));
        }
    }
    assert!(
        problems.is_empty(),
        "mutation stage:
{}",
        problems.join(
            "
"
        )
    );
}

#[test]
fn example_tests_pass() {
    assert_clean("example tests", rc::test_examples(&rc::repo_root()));
}

#[test]
fn embedded_spec_copies_match() {
    assert_clean(
        "embedded assets",
        rc::check_embedded_assets(&rc::repo_root()),
    );
}

/// `docs/diagnostics/README.md` and `docs/llms-full.txt` are generated.
/// Regenerate with `ROOTPLC_UPDATE_DOCS=1 cargo test -p rootplc-conformance`.
#[test]
fn generated_docs_are_current() {
    let root = rc::repo_root();
    let cli = std::fs::read_to_string(root.join("docs/cli/README.md")).expect("cli docs");
    let docs = [
        (
            root.join("docs/diagnostics/README.md"),
            rootplc_driver::docs::diagnostics_md(),
        ),
        (
            root.join("docs/llms-full.txt"),
            rootplc_driver::docs::llms_full(&cli),
        ),
    ];
    let update = std::env::var_os("ROOTPLC_UPDATE_DOCS").is_some();
    for (path, want) in docs {
        if update {
            std::fs::write(&path, &want).expect("write docs");
        }
        let have = std::fs::read_to_string(&path).unwrap_or_default();
        assert!(
            have == want,
            "{} is stale; run ROOTPLC_UPDATE_DOCS=1 cargo test -p rootplc-conformance",
            path.display()
        );
    }
}
