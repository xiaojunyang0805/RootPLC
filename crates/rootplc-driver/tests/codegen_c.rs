//! The C back end computes what the VM computes ([build.c.semantics]):
//! every conformance case with a `run:` line that the back end supports is
//! translated to C, compiled, run for its cycles, and every variable is
//! compared with the VM after the same cycles. Needs a C compiler (`gcc`,
//! `cc` or `clang`; on Windows also `gcc` in WSL; or `ROOTPLC_CC`); without
//! one the test reports that it was skipped.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::process::Command;

use rootplc_sema::ir::{DefKind, Program};
use rootplc_sema::{Elem, Ty};
use rootplc_vm::{Value, Vm};

const CYCLE_MS: i128 = 10;

/// How to run the compiler: a shell command prefix and a path translation.
struct Cc {
    wsl: bool,
    cc: String,
}

fn find_cc() -> Option<Cc> {
    if let Ok(cc) = std::env::var("ROOTPLC_CC") {
        return Some(Cc { wsl: false, cc });
    }
    // the compile-and-run script needs a POSIX shell
    let sh = Command::new("sh")
        .args(["-c", "true"])
        .output()
        .is_ok_and(|o| o.status.success());
    for cc in ["gcc", "cc", "clang"] {
        if sh
            && Command::new(cc)
                .arg("--version")
                .output()
                .is_ok_and(|o| o.status.success())
        {
            return Some(Cc {
                wsl: false,
                cc: cc.into(),
            });
        }
    }
    if cfg!(windows)
        && Command::new("wsl.exe")
            .args(["gcc", "--version"])
            .output()
            .is_ok_and(|o| o.status.success())
    {
        return Some(Cc {
            wsl: true,
            cc: "gcc".into(),
        });
    }
    None
}

fn wsl_path(p: &Path) -> String {
    let s = p.display().to_string().replace('\\', "/");
    match s.split_once(":/") {
        Some((drive, rest)) if drive.len() == 1 => {
            format!("/mnt/{}/{rest}", drive.to_ascii_lowercase())
        }
        _ => s,
    }
}

struct Case {
    name: String,
    program: String,
    cycles: u64,
    libraries: Vec<String>,
    path: PathBuf,
}

fn cases() -> Vec<Case> {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../conformance/cases");
    let mut out = Vec::new();
    let mut dirs = vec![root];
    while let Some(d) = dirs.pop() {
        let Ok(rd) = std::fs::read_dir(&d) else {
            continue;
        };
        let mut entries: Vec<PathBuf> = rd.filter_map(|e| e.ok().map(|e| e.path())).collect();
        entries.sort();
        for p in entries {
            if p.is_dir() {
                dirs.push(p);
                continue;
            }
            if p.extension().and_then(|e| e.to_str()) != Some("st") {
                continue;
            }
            let Ok(text) = std::fs::read_to_string(&p) else {
                continue;
            };
            let head: String = text.lines().take(15).collect::<Vec<_>>().join("\n");
            let Some(run) = head.lines().find_map(|l| l.trim().strip_prefix("run:")) else {
                continue;
            };
            let mut it = run.split_whitespace();
            let program = it.next().unwrap_or_default().to_string();
            let cycles = it
                .find_map(|w| w.strip_prefix("cycles="))
                .and_then(|n| n.parse().ok())
                .unwrap_or(1);
            let libraries = head
                .lines()
                .find_map(|l| l.trim().strip_prefix("libraries:"))
                .map(|l| {
                    l.trim_end_matches("*)")
                        .split(',')
                        .map(|x| x.trim().to_string())
                        .filter(|x| !x.is_empty())
                        .collect()
                })
                .unwrap_or_default();
            let name = p
                .strip_prefix(Path::new(env!("CARGO_MANIFEST_DIR")).join("../../conformance/cases"))
                .unwrap_or(&p)
                .display()
                .to_string()
                .replace('\\', "/");
            out.push(Case {
                name,
                program,
                cycles,
                libraries,
                path: p,
            });
        }
    }
    out.sort_by(|a, b| a.name.cmp(&b.name));
    out
}

fn elem(prog: &Program, t: &Ty) -> Option<Elem> {
    match t {
        Ty::Elem(e) => Some(*e),
        Ty::Named(i) => match &prog.defs[*i].kind {
            DefKind::Alias(a) => elem(prog, a),
            DefKind::Subrange { base, .. } => Some(*base),
            DefKind::Enum(_) => Some(Elem::Lint),
            _ => None,
        },
        _ => None,
    }
}

/// Flatten VM values the way the generated main prints them.
fn flatten(
    prog: &Program,
    out: &mut BTreeMap<String, (Option<Elem>, Value)>,
    name: &str,
    v: &Value,
    t: &Ty,
    depth: usize,
) {
    if depth > 6 {
        return;
    }
    if let Some(e) = elem(prog, t) {
        out.insert(name.to_string(), (Some(e), v.clone()));
        return;
    }
    if matches!(t, Ty::Str { .. }) {
        out.insert(name.to_string(), (None, v.clone()));
        return;
    }
    let t = match t {
        Ty::Named(i) => match &prog.defs[*i].kind {
            DefKind::Alias(a) => a.clone(),
            _ => t.clone(),
        },
        _ => t.clone(),
    };
    match (&t, v) {
        (Ty::Array { dims, elem: et }, Value::Agg(xs)) if dims.len() == 1 => {
            if let Some(Some((lo, hi))) = dims.first().copied() {
                for k in lo..=hi.min(lo + 63) {
                    if let Some(x) = xs.get((k - lo) as usize) {
                        flatten(prog, out, &format!("{name}[{k}]"), x, et, depth + 1);
                    }
                }
            }
        }
        (Ty::Named(i), Value::Agg(xs)) => {
            let fields = match &prog.defs[*i].kind {
                DefKind::Struct(f) => f.clone(),
                DefKind::Pou(p) => p.vars.clone(),
                _ => Vec::new(),
            };
            for (f, x) in fields.iter().zip(xs) {
                flatten(
                    prog,
                    out,
                    &format!("{name}.{}", f.name),
                    x,
                    &f.ty,
                    depth + 1,
                );
            }
        }
        _ => {}
    }
}

/// A string as the generated main prints it ([build.c.file]).
fn escaped(s: &str) -> String {
    let mut out = String::new();
    for ch in s.chars() {
        match ch {
            '$' => out.push_str("$$"),
            c if c as u32 == 10 => out.push_str("$N"),
            c if c as u32 == 13 => out.push_str("$R"),
            c if c as u32 == 9 => out.push_str("$T"),
            c if (c as u32) < 32 || c as u32 == 127 => out.push_str(&format!("${:02X}", c as u32)),
            c => out.push(c),
        }
    }
    out
}

fn same(e: Option<Elem>, v: &Value, c: &str) -> bool {
    let Some(e) = e else {
        return matches!(v, Value::Str(s) if escaped(s) == c);
    };
    match (e, v) {
        (Elem::Bool, Value::Bool(b)) => c == if *b { "TRUE" } else { "FALSE" },
        (Elem::Real, Value::Real(x)) => c
            .parse::<f32>()
            .is_ok_and(|y| y == *x as f32 || (y.is_nan() && x.is_nan())),
        (Elem::Lreal, Value::Real(x)) => c
            .parse::<f64>()
            .is_ok_and(|y| y == *x || (y.is_nan() && x.is_nan())),
        (_, Value::Int(n)) => c == n.to_string(),
        _ => false,
    }
}

#[test]
fn c_back_end_matches_the_vm() {
    let Some(cc) = find_cc() else {
        eprintln!("codegen_c: no C compiler found; skipped");
        return;
    };
    let dir = std::env::temp_dir().join(format!("rootplc-c-eq-{}", std::process::id()));
    std::fs::create_dir_all(&dir).expect("temp dir");
    let mut unsupported: BTreeMap<String, Vec<String>> = BTreeMap::new();
    let mut built = Vec::new();
    for (k, case) in cases().into_iter().enumerate() {
        let sources = rootplc_driver::read_sources(std::slice::from_ref(&case.path)).expect("case");
        let Ok(check) = rootplc_driver::check_sources_with(sources, &case.libraries) else {
            continue;
        };
        if !check.ok() {
            continue;
        }
        let r = rootplc_driver::build::build_c(check, Some(&case.program)).expect("build");
        match (&r.code, &r.unsupported) {
            (Some(code), _) => {
                let file = dir.join(format!("c{k}.c"));
                std::fs::write(&file, code).expect("write");
                built.push((k, case, r));
            }
            (None, Some(u)) => unsupported
                .entry(
                    u.construct
                        .split(" '")
                        .next()
                        .unwrap_or(&u.construct)
                        .to_string(),
                )
                .or_default()
                .push(case.name.clone()),
            _ => {}
        }
    }
    // compile and run all of them in one shell
    let mut script = String::from("set +e\n");
    for (k, case, _) in &built {
        let _ = std::fmt::Write::write_fmt(
            &mut script,
            format_args!(
                "{cc} -std=c99 -O1 -DROOTPLC_MAIN c{k}.c -o c{k}.exe -lm > c{k}.cc.txt 2>&1 && ./c{k}.exe {} {CYCLE_MS} > c{k}.out.txt 2>&1\n",
                case.cycles,
                cc = cc.cc
            ),
        );
    }
    std::fs::write(dir.join("run.sh"), script).expect("script");
    let status = if cc.wsl {
        Command::new("wsl.exe")
            .args(["sh", "-c", &format!("cd '{}' && sh run.sh", wsl_path(&dir))])
            .status()
    } else {
        Command::new("sh").arg("run.sh").current_dir(&dir).status()
    };
    assert!(status.is_ok(), "could not run the compiler");
    let mut equal = 0;
    let mut mismatches = Vec::new();
    for (k, case, r) in &built {
        let out = std::fs::read_to_string(dir.join(format!("c{k}.out.txt"))).unwrap_or_default();
        if !out.contains("cycles=") {
            let cc_out =
                std::fs::read_to_string(dir.join(format!("c{k}.cc.txt"))).unwrap_or_default();
            mismatches.push(format!(
                "{}: C did not compile or run:\n{}",
                case.name,
                cc_out.lines().take(8).collect::<Vec<_>>().join("\n")
            ));
            continue;
        }
        let c: BTreeMap<String, String> = out
            .lines()
            .filter_map(|l| {
                l.split_once('=')
                    .map(|(a, b)| (a.to_string(), b.to_string()))
            })
            .collect();
        // the VM, same cycles and clock
        let prog = r.check.program.as_ref().expect("program");
        let def = prog.find(&case.program).expect("program def");
        let mut vm = Vm::new(prog);
        let root = vm.instantiate(def);
        let (mut done, mut fault) = (0u64, None);
        for n in 0..case.cycles {
            vm.begin_cycle(CYCLE_MS * 1_000_000, n);
            if let Err(f) = vm.cycle(root, def) {
                fault = Some(f.kind.name().to_string());
                break;
            }
            done += 1;
            vm.advance(CYCLE_MS * 1_000_000);
        }
        let mut vals = BTreeMap::new();
        for v in &prog.pou(def).expect("pou").vars {
            if let Some(x) = vm.read_var(root, def, &v.name) {
                flatten(prog, &mut vals, &v.name, x, &v.ty, 0);
            }
        }
        let mut bad = Vec::new();
        if c.get("cycles").map(String::as_str) != Some(&done.to_string()) {
            bad.push(format!("cycles: VM {done}, C {:?}", c.get("cycles")));
        }
        if c.get("fault").cloned() != fault {
            bad.push(format!("fault: VM {fault:?}, C {:?}", c.get("fault")));
        }
        for (name, (e, v)) in &vals {
            match c.get(name) {
                Some(cv) if same(*e, v, cv) => {}
                other => bad.push(format!("{name}: VM {v:?}, C {other:?}")),
            }
        }
        if bad.is_empty() {
            equal += 1;
        } else {
            mismatches.push(format!("{}: {}", case.name, bad.join("; ")));
        }
    }
    let n_unsup: usize = unsupported.values().map(Vec::len).sum();
    eprintln!(
        "codegen_c: {} case(s) translated, {equal} equal to the VM, {} differ; {n_unsup} use constructs not supported yet:",
        built.len(),
        mismatches.len()
    );
    let mut ranked: Vec<_> = unsupported.iter().collect();
    ranked.sort_by_key(|(_, v)| std::cmp::Reverse(v.len()));
    for (what, cases) in ranked.iter().take(12) {
        eprintln!("  {:3}  {what}", cases.len());
    }
    let _ = std::fs::remove_dir_all(&dir);
    assert!(
        mismatches.is_empty(),
        "C differs from the VM:\n{}",
        mismatches.join("\n")
    );
    assert!(equal >= 40, "only {equal} cases translated and equal");
}

#[test]
fn unsupported_constructs_name_their_place() {
    let src = "FUNCTION_BLOCK FB_C\nVAR n : INT; END_VAR\nMETHOD Inc\nn := n + 1;\nEND_METHOD\nEND_FUNCTION_BLOCK\nPROGRAM P\nVAR c : FB_C; END_VAR\nc.Inc();\nEND_PROGRAM\n";
    let check =
        rootplc_driver::check_sources_with(vec![("p.st".into(), src.into())], &[]).expect("check");
    let r = rootplc_driver::build::build_c(check, None).expect("build");
    let u = r.unsupported.as_ref().expect("unsupported");
    // declarations carry no position in the IR: the POU's first statement
    assert_eq!((u.file.as_str(), u.line), ("p.st", 9));
    assert!(u.construct.contains("method"), "{}", u.construct);
    assert!(!r.ok());
}

#[test]
fn faults_stop_the_cycle_as_in_the_vm() {
    let Some(cc) = find_cc() else {
        eprintln!("codegen_c: no C compiler found; skipped");
        return;
    };
    let programs = [
        (
            "DIV_BY_ZERO",
            "PROGRAM P\nVAR d : INT := 2; q : INT; n : INT; END_VAR\nn := n + 1;\nIF n = 3 THEN d := 0; END_IF;\nq := 10 / d;\nEND_PROGRAM\n",
        ),
        (
            "INDEX",
            "PROGRAM P\nVAR a : ARRAY[1..3] OF INT; n : INT; END_VAR\nn := n + 1;\na[n] := n;\nEND_PROGRAM\n",
        ),
        (
            "RANGE",
            "TYPE T_S : INT (0..2); END_TYPE\nPROGRAM P\nVAR s : T_S; END_VAR\ns := s + 1;\nEND_PROGRAM\n",
        ),
        (
            "NULL_REF",
            "PROGRAM P\nVAR x : INT; r : REF_TO INT; n : INT; END_VAR\nn := n + 1;\nIF n < 3 THEN r := REF(x); ELSE r := NULL; END_IF;\nr^ := n;\nEND_PROGRAM\n",
        ),
    ];
    let dir = std::env::temp_dir().join(format!("rootplc-c-fault-{}", std::process::id()));
    std::fs::create_dir_all(&dir).expect("temp dir");
    let mut script = String::from("set +e\n");
    for (k, (_, src)) in programs.iter().enumerate() {
        let check = rootplc_driver::check_sources_with(vec![("p.st".into(), (*src).into())], &[])
            .expect("check");
        assert!(check.ok());
        let r = rootplc_driver::build::build_c(check, None).expect("build");
        std::fs::write(dir.join(format!("f{k}.c")), r.code.expect("code")).expect("write");
        script.push_str(&format!(
            "{cc} -std=c99 -DROOTPLC_MAIN f{k}.c -o f{k}.exe -lm && ./f{k}.exe 10 10 > f{k}.out.txt 2>&1\n",
            cc = cc.cc
        ));
    }
    std::fs::write(dir.join("run.sh"), script).expect("script");
    let _ = if cc.wsl {
        Command::new("wsl.exe")
            .args(["sh", "-c", &format!("cd '{}' && sh run.sh", wsl_path(&dir))])
            .status()
    } else {
        Command::new("sh").arg("run.sh").current_dir(&dir).status()
    };
    for (k, (kind, _)) in programs.iter().enumerate() {
        let out = std::fs::read_to_string(dir.join(format!("f{k}.out.txt"))).unwrap_or_default();
        assert!(out.contains(&format!("fault={kind}")), "{kind}: {out}");
        // the VM stops in the same cycle: two cycles done in each program
        assert!(
            out.contains("cycles=2") || *kind == "INDEX" && out.contains("cycles=3"),
            "{kind}: {out}"
        );
    }
    let _ = std::fs::remove_dir_all(&dir);
}
