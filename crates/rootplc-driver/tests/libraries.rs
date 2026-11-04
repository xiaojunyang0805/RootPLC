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

/// [stdlib.compat.unit]: a TcUnit suite runs unchanged against the bundled
/// TcUnit library and its results come back in the run report.
#[test]
fn tcunit_suite_reports_its_tests() {
    let src = r#"
FUNCTION_BLOCK FB_MathTests EXTENDS FB_TestSuite
TwoPlusTwo();
Broken();
Arrays();
Later();
METHOD TwoPlusTwo
TEST('TwoPlusTwo');
AssertEquals_INT(Expected := 4, Actual := 2 + 2, Message := 'sum');
AssertEquals_LREAL(Expected := 1.0, Actual := 1.05, Delta := 0.1, Message := 'close');
TEST_FINISHED();
END_METHOD
METHOD Broken
VAR a : INT := 5; b : INT := 6; END_VAR
TEST('Broken');
AssertEquals(Expected := a, Actual := b, Message := 'any differs');
TEST_FINISHED();
END_METHOD
METHOD Arrays
VAR x : ARRAY[1..3] OF DINT := [1, 2, 3]; y : ARRAY[0..2] OF DINT := [1, 2, 3]; END_VAR
TEST('Arrays');
AssertArrayEquals_DINT(Expecteds := x, Actuals := y, Message := 'arr');
TEST_FINISHED();
END_METHOD
METHOD Later
VAR_INST n : INT; END_VAR
TEST('Later');
n := n + 1;
IF n >= 3 THEN
    AssertTrue(n = 3, 'three cycles');
    TEST_FINISHED();
END_IF;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_TEST
VAR
    math : FB_MathTests;
END_VAR
TcUnit.RUN();
END_PROGRAM
"#;
    let check = rootplc_driver::check_sources_with(
        vec![("suite.st".into(), src.to_string())],
        &["TcUnit".to_string()],
    )
    .expect("library resolves");
    assert!(check.ok(), "suite checks");
    let run = rootplc_driver::run_report(check, Some("PRG_TEST"), 10, 10_000_000).expect("runs");
    assert!(run.fault.is_none());
    let got: Vec<(String, u8, String)> = run
        .tests
        .iter()
        .map(|t| {
            (
                format!("{}/{}", t.suite, t.test),
                t.status,
                t.message.clone(),
            )
        })
        .collect();
    assert_eq!(
        got,
        vec![
            ("PRG_TEST.math/TwoPlusTwo".into(), 0, String::new()),
            (
                "PRG_TEST.math/Broken".into(),
                1,
                "EXP: 5, ACT: 6, MSG: any differs".into()
            ),
            ("PRG_TEST.math/Arrays".into(), 0, String::new()),
            ("PRG_TEST.math/Later".into(), 0, String::new()),
        ]
    );
}
