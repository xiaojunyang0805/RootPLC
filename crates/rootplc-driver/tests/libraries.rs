//! Every bundled compatibility library checks without errors on its own
//! (with the libraries it requires). Library diagnostics are never shown to
//! users ([stdlib.compat]), so this test is what keeps the libraries honest.

#[test]
fn every_library_checks_clean() {
    for lib in rootplc_stdlib::compat::libraries() {
        let report =
            rootplc_driver::check_sources_with(Vec::new(), std::slice::from_ref(&lib.name))
                .expect("library resolves");
        let errors: Vec<String> = report
            .files
            .iter()
            .flat_map(|f| {
                f.diagnostics
                    .iter()
                    .filter(|d| d.severity == rootplc_diag::Severity::Error)
                    .map(move |d| format!("{}: {} {}", f.path.display(), d.code, d.message))
            })
            .collect();
        assert!(errors.is_empty(), "{}:\n{}", lib.name, errors.join("\n"));
    }
}
