//! WebAssembly bindings for the zero-install browser playground.
//!
//! Roadmap phase: pulled forward for the investor demo (2026-11-03). No
//! wasm-bindgen and no `unsafe`: the page writes UTF-8 input into a buffer
//! (`input_reserve` returns its address), calls a command, and reads the
//! UTF-8 JSON result from `output_ptr` / `output_len`.
//!
//! Commands: `check`, `test`, `run(cycles, cycle_ms)` on the input source,
//! and a simulation session that keeps the VM alive between steps:
//! `sim_start` (compile, instantiate the only PROGRAM, list its variables),
//! `sim_step(cycles, cycle_ms)` (input buffer = `name=value` lines to set
//! first) returning the variables after the step.

// FFI boundary (ARCHITECTURE rule 5): `#[unsafe(no_mangle)]` is needed to
// export these functions to the browser. It is the only unsafe attribute in
// the workspace; no unsafe operation is performed anywhere in this crate.
#![allow(unsafe_code)]

use std::cell::RefCell;
use std::path::PathBuf;

use rootplc_diag::json_string;
use rootplc_sema::Ty;
use rootplc_sema::ir::{PouKind, Program};
use rootplc_vm::{Value, Vm};

struct Session {
    vm: Vm<'static>,
    prog: &'static Program,
    root: usize,
    def: usize,
}

thread_local! {
    static INPUT: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
    static OUTPUT: RefCell<Vec<u8>> = const { RefCell::new(Vec::new()) };
    static SESSION: RefCell<Option<Session>> = const { RefCell::new(None) };
}

fn input() -> String {
    INPUT.with(|b| String::from_utf8_lossy(&b.borrow()).into_owned())
}

fn output(s: String) -> u32 {
    OUTPUT.with(|b| {
        let mut b = b.borrow_mut();
        *b = s.into_bytes();
        b.len() as u32
    })
}

fn sources() -> Vec<(PathBuf, String)> {
    vec![(PathBuf::from("playground.st"), input())]
}

/// Reserve `len` bytes of input; returns the buffer address for the page to fill.
#[unsafe(no_mangle)]
pub extern "C" fn input_reserve(len: u32) -> u32 {
    INPUT.with(|b| {
        let mut b = b.borrow_mut();
        b.clear();
        b.resize(len as usize, 0);
        b.as_mut_ptr() as usize as u32
    })
}

/// Address of the last result.
#[unsafe(no_mangle)]
pub extern "C" fn output_ptr() -> u32 {
    OUTPUT.with(|b| b.borrow().as_ptr() as usize as u32)
}

/// Length of the last result.
#[unsafe(no_mangle)]
pub extern "C" fn output_len() -> u32 {
    OUTPUT.with(|b| b.borrow().len() as u32)
}

/// `rootplc check` on the input source.
#[unsafe(no_mangle)]
pub extern "C" fn check() -> u32 {
    output(rootplc_driver::json::check(&rootplc_driver::check_sources(
        sources(),
    )))
}

/// `rootplc test` on the input source.
#[unsafe(no_mangle)]
pub extern "C" fn test() -> u32 {
    let r = rootplc_driver::test_report(rootplc_driver::check_sources(sources()), None);
    output(rootplc_driver::json::test(&r))
}

/// `rootplc run` on the input source.
#[unsafe(no_mangle)]
pub extern "C" fn run(cycles: u32, cycle_ms: u32) -> u32 {
    let check = rootplc_driver::check_sources(sources());
    let s = match rootplc_driver::run_report(
        check,
        None,
        u64::from(cycles.max(1)),
        i128::from(cycle_ms) * 1_000_000,
    ) {
        Ok(r) => rootplc_driver::json::run(&r),
        Err(e) => rootplc_driver::json::error("run", &e),
    };
    output(s)
}

fn type_name(prog: &Program, t: &Ty) -> String {
    match t {
        Ty::Elem(e) => e.name().to_string(),
        Ty::Str { .. } => "STRING".into(),
        Ty::Named(i) => prog.defs[*i].name.clone(),
        Ty::Array { .. } => "ARRAY".into(),
        Ty::Ref(_) => "REF".into(),
        _ => "?".into(),
    }
}

fn vars_json(s: &Session) -> String {
    let Some(pou) = s.prog.pou(s.def) else {
        return "{}".into();
    };
    let items: Vec<String> = pou
        .vars
        .iter()
        .filter_map(|v| s.vm.read_var(s.root, s.def, &v.name).map(|x| (v, x)))
        .map(|(v, x)| {
            format!(
                "{}:{}",
                json_string(&v.name),
                json_string(&s.vm.display(x, &v.ty))
            )
        })
        .collect();
    format!("{{{}}}", items.join(","))
}

/// Compile the input source and instantiate its PROGRAM for stepping.
#[unsafe(no_mangle)]
pub extern "C" fn sim_start() -> u32 {
    let check = rootplc_driver::check_sources(sources());
    let report = rootplc_driver::json::check(&check);
    let Some(prog) = check.program else {
        SESSION.with(|s| *s.borrow_mut() = None);
        return output(format!("{{\"ok\":false,\"check\":{report}}}"));
    };
    // The program lives for the rest of the page session.
    let prog: &'static Program = Box::leak(Box::new(prog));
    let programs: Vec<usize> = (0..prog.defs.len())
        .filter(|&i| matches!(prog.pou(i), Some(p) if p.kind == PouKind::Program))
        .collect();
    let Some(&def) = programs.first() else {
        return output("{\"ok\":false,\"message\":\"the source has no PROGRAM\"}".into());
    };
    let mut vm = Vm::new(prog);
    let root = vm.instantiate(def);
    let pou = prog.pou(def).map(|p| p.vars.clone()).unwrap_or_default();
    let decl: Vec<String> = pou
        .iter()
        .map(|v| {
            format!(
                "{{\"name\":{},\"type\":{},\"section\":\"{:?}\"}}",
                json_string(&v.name),
                json_string(&type_name(prog, &v.ty)),
                v.section
            )
        })
        .collect();
    let session = Session {
        vm,
        prog,
        root,
        def,
    };
    let s = format!(
        "{{\"ok\":true,\"program\":{},\"declarations\":[{}],\"vars\":{},\"check\":{report}}}",
        json_string(&prog.defs[def].name),
        decl.join(","),
        vars_json(&session)
    );
    SESSION.with(|x| *x.borrow_mut() = Some(session));
    output(s)
}

fn parse_value(text: &str) -> Value {
    let t = text.trim();
    match t.to_ascii_uppercase().as_str() {
        "TRUE" => Value::Bool(true),
        "FALSE" => Value::Bool(false),
        _ => {
            if let Ok(n) = t.parse::<i128>() {
                Value::Int(n)
            } else if let Ok(x) = t.parse::<f64>() {
                Value::Real(x)
            } else {
                Value::Str(t.to_string())
            }
        }
    }
}

/// Set inputs (`name=value` lines in the input buffer), then run `cycles`
/// cycles of `cycle_ms` virtual milliseconds each.
#[unsafe(no_mangle)]
pub extern "C" fn sim_step(cycles: u32, cycle_ms: u32) -> u32 {
    let assignments = input();
    let s = SESSION.with(|x| {
        let mut x = x.borrow_mut();
        let Some(s) = x.as_mut() else {
            return "{\"ok\":false,\"message\":\"call sim_start first\"}".to_string();
        };
        for line in assignments.lines() {
            if let Some((n, v)) = line.split_once('=') {
                s.vm.write_var(s.root, s.def, n.trim(), parse_value(v));
            }
        }
        let mut fault = String::from("null");
        for _ in 0..cycles {
            if let Err(f) = s.vm.cycle(s.root, s.def) {
                fault = format!(
                    "{{\"kind\":\"{}\",\"message\":{}}}",
                    f.kind.name(),
                    json_string(&f.message)
                );
                break;
            }
            s.vm.advance(i128::from(cycle_ms) * 1_000_000);
        }
        format!(
            "{{\"ok\":{},\"time_ms\":{},\"fault\":{fault},\"vars\":{}}}",
            fault == "null",
            s.vm.now_ns / 1_000_000,
            vars_json(s)
        )
    });
    output(s)
}
