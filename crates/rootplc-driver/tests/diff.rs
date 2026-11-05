//! `rootplc diff` ([diff.command] … [diff.limits]) on the conformance cases
//! in conformance/cases/diff and on small inline projects.

use std::path::{Path, PathBuf};

use rootplc_driver::diff::{DiffOptions, Verdict, diff, render, to_json};

fn repo() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("../..")
}

fn case(name: &str) -> rootplc_driver::CheckReport {
    let sources = rootplc_driver::read_sources(&[repo().join("conformance/cases/diff").join(name)])
        .expect("case");
    let check = rootplc_driver::check_sources_with(sources, &[]).expect("check");
    assert!(check.ok(), "{name} does not compile");
    check
}

fn inline(src: &str, libs: &[&str]) -> rootplc_driver::CheckReport {
    let libs: Vec<String> = libs.iter().map(|s| s.to_string()).collect();
    let check =
        rootplc_driver::check_sources_with(vec![(PathBuf::from("inline.st"), src.into())], &libs)
            .expect("check");
    assert!(check.ok(), "inline source does not compile");
    check
}

fn opts(reference: &str, unit: &str) -> DiffOptions {
    DiffOptions {
        reference: reference.into(),
        unit: unit.into(),
        ..DiffOptions::default()
    }
}

#[test]
fn an_adapter_with_the_reference_names_agrees() {
    let check = case("ok_diff_adapter_agrees.st");
    let r = diff(&check, &opts("FB_RefLatch", "FB_LatchAdapter")).expect("diff");
    assert_eq!(r.verdict, Verdict::Agree);
    assert_eq!(r.cycles, 1000);
    assert_eq!(r.driven, ["Start", "StopOk", "Limit", "Level"]);
    assert!(r.outputs.iter().all(|o| o.differing == 0));
    assert!(r.first.is_none());
    assert!(render(&r).contains("agree (1000 cycles, seed 1)"));
    // the real block itself has other names: nothing to compare
    let r = diff(&check, &opts("FB_RefLatch", "FB_PumpLatch")).expect("diff");
    assert_eq!(r.missing_inputs.len(), 4);
    assert_eq!(r.missing_outputs, ["Out", "High"]);
    assert!(r.outputs.is_empty());
}

#[test]
fn a_difference_is_found_and_reproducible() {
    let check = case("ok_diff_finds_a_difference.st");
    let r = diff(&check, &opts("FB_StopWins", "FB_StartWins")).expect("diff");
    assert_eq!(r.verdict, Verdict::Differ);
    assert_eq!(r.held, ["Delay"]);
    let f = r.first.as_ref().expect("first difference");
    assert_eq!(f.output, "Out");
    assert_eq!((f.reference.as_str(), f.unit.as_str()), ("FALSE", "TRUE"));
    // the trace ends with the cycle of the difference: start and stop together
    let (c, row) = f.trace.last().expect("trace");
    assert_eq!(*c, f.cycle);
    assert!(row.contains(&("Start".into(), "TRUE".into())));
    assert!(row.contains(&("StopOk".into(), "FALSE".into())));
    // the last input changes up to the difference, oldest first
    assert!(!f.changes.is_empty() && f.changes.len() <= 8);
    assert!(f.changes.iter().all(|(c, _, _)| *c <= f.cycle));
    assert!(f.changes.windows(2).all(|w| w[0].0 <= w[1].0));
    assert!(to_json(&r).contains("\"changes\":[{\"cycle\":"));
    assert!(render(&r).contains("last input changes before it:"));
    // the same seed gives the same run; another seed another one
    let again = diff(&check, &opts("FB_StopWins", "FB_StartWins")).expect("diff");
    assert_eq!(again.outputs[0].differing, r.outputs[0].differing);
    let mut o = opts("FB_StopWins", "FB_StartWins");
    o.seed = 99;
    let other = diff(&check, &o).expect("diff");
    assert_ne!(other.outputs[0].differing, r.outputs[0].differing);
    // with the stop held healthy the difference cannot occur
    let mut o = opts("FB_StopWins", "FB_StartWins");
    o.set = vec![("stopok".into(), "TRUE".into())];
    let r = diff(&check, &o).expect("diff");
    assert_eq!(r.verdict, Verdict::Agree);
    assert_eq!(r.set, [("StopOk".to_string(), "TRUE".to_string())]);
    let json = to_json(&r);
    assert!(json.starts_with("{\"command\":\"diff\",\"ok\":true,"));
    assert!(json.contains("\"verdict\":\"agree\""));
}

#[test]
fn durations_ranges_and_tolerance() {
    let src = "
FUNCTION_BLOCK FB_A
VAR_INPUT x : REAL; n : INT; d : TIME; END_VAR
VAR_OUTPUT y : REAL; m : INT; t : TIME; END_VAR
y := x * 2.0; m := n; t := d;
END_FUNCTION_BLOCK
FUNCTION_BLOCK FB_B
VAR_INPUT x : REAL; n : INT; d : TIME; END_VAR
VAR_OUTPUT y : REAL; m : INT; t : TIME; END_VAR
y := x + x + 0.00001; m := n; t := d;
IF n > 7 THEN m := 0; END_IF;
END_FUNCTION_BLOCK";
    let check = inline(src, &[]);
    // integers stay within 0 .. 7: the branch is never taken
    let mut o = opts("FB_A", "FB_B");
    o.ranges = vec![("n".into(), 0.0, 7.0), ("x".into(), -5.0, 5.0)];
    o.set = vec![("d".into(), "T#1s500ms".into())];
    o.toggle = 0.5;
    let r = diff(&check, &o).expect("diff");
    assert_eq!(r.verdict, Verdict::Agree, "{}", render(&r));
    // a tolerance smaller than the offset finds it
    o.tolerance = 0.000001;
    let r = diff(&check, &o).expect("diff");
    assert_eq!(r.verdict, Verdict::Differ);
    assert_eq!(r.outputs[0].name, "y");
    assert!(r.outputs[1].differing == 0 && r.outputs[2].differing == 0);
    // the default range reaches the branch
    let r = diff(&check, &opts("FB_A", "FB_B")).expect("diff");
    assert!(r.outputs[1].differing > 0);
    assert_eq!(r.held, ["d"]);
}

#[test]
fn set_durations_reach_timers() {
    // the set time drives a timer: agreement needs the exact duration
    let src = "
FUNCTION_BLOCK FB_Ref
VAR_INPUT x : BOOL; d : TIME; ld : LTIME; END_VAR
VAR_OUTPUT q : BOOL; long : BOOL; END_VAR
VAR t : TON; END_VAR
t(IN := x, PT := d);
q := t.Q;
long := ld > LT#1s;
END_FUNCTION_BLOCK
FUNCTION_BLOCK FB_Fixed
VAR_INPUT x : BOOL; d : TIME; ld : LTIME; END_VAR
VAR_OUTPUT q : BOOL; long : BOOL; END_VAR
VAR t : TON; END_VAR
t(IN := x, PT := T#150ms);
q := t.Q;
long := TRUE;
END_FUNCTION_BLOCK";
    let check = inline(src, &[]);
    let mut o = opts("FB_Ref", "FB_Fixed");
    o.set = vec![
        ("d".into(), "T#150ms".into()),
        ("ld".into(), "LT#2s".into()),
    ];
    let r = diff(&check, &o).expect("diff");
    assert_eq!(r.verdict, Verdict::Agree, "{}", render(&r));
    o.set = vec![
        ("d".into(), "T#160ms".into()),
        ("ld".into(), "LT#2s".into()),
    ];
    let r = diff(&check, &o).expect("diff");
    assert_eq!(r.verdict, Verdict::Differ);
    assert_eq!(r.outputs[0].name, "q");
    assert_eq!(r.outputs[1].differing, 0);
}

#[test]
fn the_task_information_is_filled() {
    // a block that reads its task's cycle time (TwinCAT _TaskInfo)
    let src = "
FUNCTION_BLOCK FB_TaskRamp
VAR_INPUT x : BOOL; END_VAR
VAR_OUTPUT ms : UDINT; n : UDINT; END_VAR
ms := _TaskInfo[1].CycleTime / 10000;
n := _TaskInfo[1].CycleCount;
END_FUNCTION_BLOCK
FUNCTION_BLOCK FB_Fixed
VAR_INPUT x : BOOL; END_VAR
VAR_OUTPUT ms : UDINT; n : UDINT; END_VAR
VAR c : UDINT; END_VAR
ms := 20;
n := c;
c := c + 1;
END_FUNCTION_BLOCK";
    let check = inline(src, &["TwinCAT_BuiltIns"]);
    let mut o = opts("FB_TaskRamp", "FB_Fixed");
    o.cycle_ms = 20;
    let r = diff(&check, &o).expect("diff");
    assert_eq!(r.verdict, Verdict::Agree, "{}", render(&r));
}

#[test]
fn enumeration_values_and_libraries() {
    let src = "
FUNCTION_BLOCK FB_MyMotor
VAR_INPUT
    Mode : RB_MODE; AutoRun, ManRun, Interlock : BOOL; Permissive : BOOL := TRUE;
    FbRunning, Overload : BOOL; Feedback : BOOL := TRUE;
    FeedbackTime : TIME := T#2s; RestartDelay : TIME; Reset : BOOL;
END_VAR
VAR_OUTPUT Run, Running : BOOL; END_VAR
Run := Mode = RB_MODE#Auto AND AutoRun AND NOT Interlock;
Running := FbRunning;
END_FUNCTION_BLOCK";
    let check = inline(src, &["RootBlocks"]);
    let mut o = opts("RB_Motor", "FB_MyMotor");
    o.set = vec![
        ("Mode".into(), "RB_MODE#Auto".into()),
        ("Feedback".into(), "FALSE".into()),
        ("Overload".into(), "FALSE".into()),
        ("Permissive".into(), "TRUE".into()),
    ];
    let r = diff(&check, &o).expect("diff");
    // without feedback supervision Running follows Run in RB_Motor: differs
    assert_eq!(r.verdict, Verdict::Differ);
    let run = r.outputs.iter().find(|x| x.name == "Run").expect("Run");
    assert_eq!(run.differing, 0, "{}", render(&r));
    assert!(r.missing_outputs.contains(&"Error".to_string()));
    assert!(r.held.contains(&"FeedbackTime".to_string()));
    // a reference-only input can be set: a unit without a mode
    let src2 = "
FUNCTION_BLOCK FB_Bare
VAR_INPUT AutoRun, Interlock : BOOL; END_VAR
VAR_OUTPUT Run : BOOL; END_VAR
Run := AutoRun AND NOT Interlock;
END_FUNCTION_BLOCK";
    let check2 = inline(src2, &["RootBlocks"]);
    let mut o = opts("RB_Motor", "FB_Bare");
    o.set = vec![
        ("Mode".into(), "RB_MODE#Auto".into()),
        ("Feedback".into(), "FALSE".into()),
    ];
    let r = diff(&check2, &o).expect("diff");
    assert_eq!(r.verdict, Verdict::Agree, "{}", render(&r));
    assert!(!r.missing_inputs.contains(&"Mode".to_string()));
    assert!(r.missing_inputs.contains(&"ManRun".to_string()));
    let mut o = opts("RB_Motor", "FB_MyMotor");
    o.set = vec![("Mode".into(), "RB_MODE#Fast".into())];
    assert!(
        diff(&check, &o)
            .expect_err("refused")
            .contains("no value Fast")
    );
}

#[test]
fn faults_and_refusals() {
    let src = "
FUNCTION_BLOCK FB_Ok
VAR_INPUT n : INT; END_VAR
VAR_OUTPUT q : INT; END_VAR
q := n;
END_FUNCTION_BLOCK
FUNCTION_BLOCK FB_Div
VAR_INPUT n : INT; END_VAR
VAR_OUTPUT q : INT; END_VAR
q := 100 / n;
END_FUNCTION_BLOCK
FUNCTION_BLOCK FB_InOut
VAR_IN_OUT n : INT; END_VAR
VAR_OUTPUT q : INT; END_VAR
q := n;
END_FUNCTION_BLOCK
FUNCTION F_Not : BOOL VAR_INPUT x : BOOL; END_VAR F_Not := NOT x; END_FUNCTION";
    let check = inline(src, &[]);
    let r = diff(&check, &opts("FB_Ok", "FB_Div")).expect("diff");
    assert_eq!(r.verdict, Verdict::Fault);
    let fault = r.fault.as_deref().expect("fault");
    assert!(fault.starts_with("FB_Div: "), "{fault}");
    assert!(r.cycles < 1000);
    assert!(
        diff(&check, &opts("FB_Ok", "FB_InOut"))
            .expect_err("refused")
            .contains("VAR_IN_OUT")
    );
    assert!(
        diff(&check, &opts("FB_Ok", "F_Not"))
            .expect_err("refused")
            .contains("not a FUNCTION_BLOCK")
    );
    assert!(
        diff(&check, &opts("FB_Ok", "FB_Nope"))
            .expect_err("refused")
            .contains("no FUNCTION_BLOCK")
    );
    let mut o = opts("FB_Ok", "FB_Div");
    o.set = vec![("x".into(), "1".into())];
    assert!(
        diff(&check, &o)
            .expect_err("refused")
            .contains("not an input")
    );
    let mut o = opts("FB_Ok", "FB_Div");
    o.ranges = vec![("n".into(), 5.0, 1.0)];
    assert!(diff(&check, &o).expect_err("refused").contains("above"));
    let mut o = opts("FB_Ok", "FB_Div");
    o.set = vec![("n".into(), "lots".into())];
    assert!(
        diff(&check, &o)
            .expect_err("refused")
            .contains("cannot read")
    );
}

#[test]
fn only_the_files_the_blocks_need_are_compiled() {
    let dir = repo().join("conformance/cases/diff");
    let mut sources = rootplc_driver::read_sources(&[dir.join("ok_diff_slice.st")]).expect("case");
    // unrelated parts of the same project, one of them broken
    sources.push((
        PathBuf::from("broken.st"),
        "PROGRAM P VAR x : INT; END_VAR x := ; END_PROGRAM".into(),
    ));
    sources.push((
        PathBuf::from("other.st"),
        "FUNCTION_BLOCK FB_Other VAR_OUTPUT y : BOOL; END_VAR y := TRUE; END_FUNCTION_BLOCK".into(),
    ));
    // the whole project does not compile
    let whole = rootplc_driver::check_sources_with(sources.clone(), &[]).expect("check");
    assert!(!whole.ok());
    let mut o = opts("FB_Ref", "FB_Uses");
    o.ranges = vec![("x".into(), 0.0, 100.0)];
    let run = rootplc_driver::diff::diff_sources(sources.clone(), &[], &o).expect("diff");
    let rootplc_driver::diff::DiffRun::Report(r) = run else {
        panic!("the slice should compile");
    };
    assert_eq!(r.verdict, Verdict::Agree, "{}", render(&r));
    assert_eq!(r.left_out, ["broken.st", "other.st"]);
    assert!(to_json(&r).contains("\"left_out\":[\"broken.st\",\"other.st\"]"));
    // the slice follows dependencies across files
    let (kept, left) = rootplc_driver::diff::slice(
        vec![
            (PathBuf::from("a.st"), "FUNCTION_BLOCK A VAR h : B; END_VAR END_FUNCTION_BLOCK".into()),
            (PathBuf::from("b.st"), "FUNCTION_BLOCK B VAR_INPUT m : E_M; END_VAR IF m = E_M#On THEN END_IF; END_FUNCTION_BLOCK".into()),
            (PathBuf::from("t.st"), "TYPE E_M : (Off, On); END_TYPE".into()),
            (PathBuf::from("g.st"), "NAMESPACE G VAR_GLOBAL c : INT; END_VAR END_NAMESPACE".into()),
            (PathBuf::from("u.st"), "FUNCTION_BLOCK U END_FUNCTION_BLOCK".into()),
        ],
        &["a"],
    );
    let kept: Vec<_> = kept.iter().map(|(p, _)| p.display().to_string()).collect();
    assert_eq!(kept, ["a.st", "b.st", "t.st"]);
    assert_eq!(left.len(), 2);
    // a broken file the blocks need still stops the comparison
    sources.push((
        PathBuf::from("helper2.st"),
        "FUNCTION_BLOCK FB_Helper VAR_OUTPUT q : BOOL; END_VAR q := ; END_FUNCTION_BLOCK".into(),
    ));
    let run = rootplc_driver::diff::diff_sources(sources, &[], &o).expect("diff");
    assert!(matches!(
        run,
        rootplc_driver::diff::DiffRun::NotCompiling(_)
    ));
}
