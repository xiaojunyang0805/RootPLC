//! Spec, diagnostic registry and conformance cases must agree.

#[test]
fn spec_registry_and_cases_are_consistent() {
    let root = rootplc_conformance::repo_root();
    let problems = rootplc_conformance::check_consistency(&root).expect("suite loads");
    assert!(
        problems.is_empty(),
        "{} problem(s):\n{}",
        problems.len(),
        problems.join("\n")
    );
}
