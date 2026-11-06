//! `rootplc sim` (spec/17-simulation.md) on the conformance case
//! `sim/ok_sim_tank.st` and small inline projects.

use std::path::{Path, PathBuf};

use rootplc_driver::sim::{SimReport, SimRun, compare, read_trace, sim_sources, trace_csv};

fn tank() -> Vec<(PathBuf, String)> {
    let p =
        Path::new(env!("CARGO_MANIFEST_DIR")).join("../../conformance/cases/sim/ok_sim_tank.st");
    rootplc_driver::read_sources(&[p]).expect("case")
}

const SCENARIO: &str = "# tank level control with its plant
programs PRG_Plant PRG_Main
cycle T#100ms
duration T#120s
record rLevel bPump PRG_Main.nSwitches
at T#0s set PRG_Main.bStart := TRUE
at T#1s expect bPump = TRUE
from T#60s to T#120s expect rLevel >= 39.0
from T#60s to T#120s expect rLevel <= 61.0
at T#120s expect PRG_Main.nSwitches >= 2
";

fn report(sources: Vec<(PathBuf, String)>, scenario: &str, old: Option<&str>) -> SimReport {
    match sim_sources(sources, &[], scenario, old).expect("scenario runs") {
        SimRun::Report(r) => *r,
        SimRun::NotCompiling(c) => panic!("does not compile: {:?}", c.files),
    }
}

#[test]
fn controller_and_plant_meet_the_scenario() {
    let r = report(tank(), SCENARIO, None);
    assert!(r.ok(), "{}", rootplc_driver::sim::render(&r));
    assert_eq!(r.cycles, 1200);
    assert_eq!(r.expectations.len(), 4);
    assert!(r.expectations.iter().all(|e| e.checked && e.ok));
    assert_eq!(r.trace.rows.len(), 1200);
    assert_eq!(r.trace.paths, ["rLevel", "bPump", "PRG_Main.nSwitches"]);
    // the pump starts in the first cycle (level 0, below 40)
    assert_eq!(r.trace.rows[0].2[1], "TRUE");
    assert_eq!(r.trace.rows[1].1, 100);
    let json = rootplc_driver::sim::to_json(&r);
    assert!(json.starts_with("{\"command\":\"sim\",\"ok\":true,\"cycles\":1200,"));
}

#[test]
fn a_run_compares_equal_with_its_own_trace() {
    let first = report(tank(), SCENARIO, None);
    let csv = trace_csv(&first.trace);
    let again = report(tank(), SCENARIO, Some(&csv));
    let c = again.compare.as_ref().expect("compared");
    assert!(c.equal(), "{c:?}");
    assert!(again.ok());
}

#[test]
fn a_changed_controller_differs_from_the_trace() {
    let csv = trace_csv(&report(tank(), SCENARIO, None).trace);
    // a lower switch-off level: the pump stops earlier the first time
    let mut changed = tank();
    changed[0].1 = changed[0]
        .1
        .replace("rHigh : REAL := 60.0", "rHigh : REAL := 55.0");
    let r = report(changed, SCENARIO, Some(&csv));
    let d = r
        .compare
        .as_ref()
        .and_then(|c| c.first.clone())
        .expect("a difference");
    assert_eq!(d.path, "bPump");
    assert_eq!((d.trace.as_str(), d.run.as_str()), ("TRUE", "FALSE"));
    assert!(!r.ok());
}

#[test]
fn failing_expectations_report_cycle_and_value() {
    let scenario = "programs PRG_Plant PRG_Main
cycle T#100ms
duration T#10s
at T#0s set PRG_Main.bStart := TRUE
at T#2s expect rLevel > 50.0
from T#0s to T#10s expect bPump = FALSE
at T#1h expect PRG_Main.bRunning = TRUE
";
    let r = report(tank(), scenario, None);
    assert!(!r.ok());
    let e = &r.expectations;
    let (c, ms, v) = e[0].failed.clone().expect("fails");
    assert_eq!((c, ms), (20, 2000));
    assert!(v.starts_with("2.") || v.starts_with('3'), "{v}");
    // interval: first failing cycle
    assert_eq!(e[1].failed.as_ref().map(|f| f.0), Some(0));
    // a time after the end refers to the last cycle
    assert!(e[2].checked && e[2].ok);
}

#[test]
fn scenario_errors_are_reported() {
    let bad = |s: &str| match sim_sources(tank(), &[], s, None) {
        Err(e) => e,
        Ok(_) => panic!("accepted: {s}"),
    };
    assert!(bad("duration T#1s").contains("'programs' is missing"));
    assert!(bad("programs PRG_Main").contains("'duration' is missing"));
    assert!(bad("programs PRG_Nope\nduration T#1s").contains("no PROGRAM named 'PRG_Nope'"));
    assert!(
        bad("programs PRG_Main\nduration T#1s\nat T#0s set PRG_Main.nope := 1")
            .contains("no variable 'nope'")
    );
    assert!(bad("programs PRG_Main\nduration T#1s\nat T#0s expect x ~ 1").contains("line 3"));
    assert!(bad("programs PRG_Main\nduration soon").contains("not a duration"));
    assert!(bad("programs PRG_Main\nduration T#1s\njump").contains("unknown statement 'jump'"));
}

#[test]
fn paths_into_instances_structures_and_arrays() {
    let src = "TYPE ST_Pos : STRUCT x : INT; y : INT; END_STRUCT; END_TYPE
FUNCTION_BLOCK FB_Axis
VAR_INPUT target : ST_Pos; END_VAR
VAR_OUTPUT pos : ST_Pos; END_VAR
pos := target;
END_FUNCTION_BLOCK
PROGRAM P
VAR ax : FB_Axis; log : ARRAY[1..3] OF INT; k : INT := 1; name : STRING := 'idle'; END_VAR
ax();
log[k] := ax.pos.x;
k := k MOD 3 + 1;
END_PROGRAM
";
    let scenario = "programs P
duration T#30ms
record P.log[1] P.log[2] P.name
at T#0s set P.ax.target.x := 7
at T#10ms set P.ax.target.x := 8
at T#10ms set P.name := 'run, then $'stop$''
at T#20ms expect P.log[2] = 8
at T#20ms expect P.ax.pos.x = 8
at T#20ms expect P.name = 'run, then $'stop$''
";
    let r = report(vec![(PathBuf::from("p.st"), src.into())], scenario, None);
    assert!(r.ok(), "{}", rootplc_driver::sim::render(&r));
    assert_eq!(r.trace.rows[0].2[0], "7");
    // a value with a comma and quotes survives the CSV round trip
    let csv = trace_csv(&r.trace);
    let back = read_trace(&csv).expect("reads");
    assert_eq!(back.rows, r.trace.rows);
    assert!(compare(&back, &r.trace).equal());
}

#[test]
fn a_fault_stops_the_run() {
    let src = "PROGRAM P
VAR d : INT; q : INT; END_VAR
q := 10 / d;
END_PROGRAM
";
    let scenario = "programs P
duration T#1s
at T#0s set P.d := 2
at T#50ms set P.d := 0
at T#500ms expect P.q = 5
";
    let r = report(vec![(PathBuf::from("p.st"), src.into())], scenario, None);
    let (c, f) = r.fault.as_ref().expect("fault");
    assert_eq!(*c, 5);
    assert_eq!(f.kind.name(), "DIV_BY_ZERO");
    assert_eq!(r.cycles, 5);
    assert!(!r.expectations[0].checked);
    assert!(!r.ok());
}
