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
