//! `rootplc test --slice` ([tests.slice]) on the conformance case and an
//! inline project with a broken unrelated file.

use std::path::{Path, PathBuf};

use rootplc_driver::slice::slice_tests;

fn repo() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn project() -> Vec<(PathBuf, String)> {
    let mut sources = rootplc_driver::read_sources(&[
        repo().join("conformance/cases/test-blocks/ok_tests_slice.st")
    ])
    .expect("case");
    // a test in another file that uses a block from a third file
    sources.push((
        PathBuf::from("lamp_test.st"),
        "TEST lamp_on\nVAR l : FB_Lamp; END_VAR\nl(on := TRUE);\nASSERT_TRUE(l.out);\nEND_TEST\n"
            .into(),
    ));
    sources.push((
        PathBuf::from("lamp.st"),
        "FUNCTION_BLOCK FB_Lamp\nVAR_INPUT on : BOOL; END_VAR\nVAR_OUTPUT out : BOOL; END_VAR\nout := on;\nEND_FUNCTION_BLOCK\n".into(),
    ));
    // unrelated parts of the project, one broken
    sources.push((
        PathBuf::from("broken.st"),
        "PROGRAM P VAR x : INT; END_VAR x := ; END_PROGRAM".into(),
    ));
    sources.push((
        PathBuf::from("unused.st"),
        "FUNCTION_BLOCK FB_Unused VAR_OUTPUT y : BOOL; END_VAR y := TRUE; END_FUNCTION_BLOCK"
            .into(),
    ));
    sources
}

#[test]
fn tests_run_on_the_files_they_need() {
    let sources = project();
    let whole = rootplc_driver::check_sources_with(sources.clone(), &[]).expect("check");
    assert!(!whole.ok(), "the whole project does not compile");
    let (kept, left) = slice_tests(sources);
    let kept_names: Vec<String> = kept
        .iter()
        .map(|(p, _)| {
            p.file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string()
        })
        .collect();
    assert_eq!(kept_names, ["ok_tests_slice.st", "lamp_test.st", "lamp.st"]);
    assert_eq!(
        left,
        [PathBuf::from("broken.st"), PathBuf::from("unused.st")]
    );
    let check = rootplc_driver::check_sources_with(kept, &[]).expect("check");
    assert!(check.ok());
    let report = rootplc_driver::test_report(check, None);
    assert!(report.ok());
    assert_eq!(report.outcomes.len(), 2);
}

#[test]
fn mutation_on_the_slice() {
    let (kept, _) = slice_tests(project());
    let m = rootplc_driver::mutate::mutation_report(kept, &[], None, 1000).expect("mutate");
    assert!(m.error.is_none(), "{:?}", m.error);
    assert!(m.mutants.iter().all(|(mu, _)| {
        let n = mu.path.to_string_lossy();
        !n.contains("broken") && !n.contains("unused")
    }));
    assert!(!m.mutants.is_empty());
}

#[test]
fn a_tcunit_test_call_is_not_a_test_block() {
    let (kept, _) = slice_tests(vec![
        (
            PathBuf::from("suite.st"),
            "FUNCTION_BLOCK Suite
TEST('adds');
TEST_FINISHED();
END_FUNCTION_BLOCK"
                .into(),
        ),
        (
            PathBuf::from("t.st"),
            "TEST real_one
ASSERT_TRUE(TRUE);
END_TEST"
                .into(),
        ),
    ]);
    let names: Vec<_> = kept.iter().map(|(p, _)| p.display().to_string()).collect();
    assert_eq!(names, ["t.st"]);
}

#[test]
fn no_tests_keeps_nothing() {
    let (kept, left) = slice_tests(vec![(
        PathBuf::from("a.st"),
        "FUNCTION_BLOCK A END_FUNCTION_BLOCK".into(),
    )]);
    assert!(kept.is_empty());
    assert_eq!(left.len(), 1);
}
