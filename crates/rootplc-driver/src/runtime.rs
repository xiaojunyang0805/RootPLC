//! `rootplc runtime`: runtime v0 (spec/14-runtime.md). The VM, wrapped as an
//! ABI [`Program`] for `rootplc-runtime`, which never sees the compiler.

use std::sync::atomic::AtomicBool;

use rootplc_abi::{Kind, Program, Scalar, VarInfo};
use rootplc_runtime::{Clock, Config, IoDriver, Report, Runtime};
use rootplc_sema::ir::{self, DefKind, PouKind};
use rootplc_sema::{Elem, Ty};
use rootplc_vm::{Value, Vm};

use crate::CheckReport;
use crate::json::location;

/// Where a runtime variable lives in the VM.
struct Slot {
    root: usize,
    def: usize,
    name: String,
    ty: Ty,
}

/// The VM running one PROGRAM, as the runtime sees it.
pub struct VmProgram<'p> {
    vm: Vm<'p>,
    check: &'p CheckReport,
    root: usize,
    def: usize,
    cycle: u64,
    period_ns: i128,
    vars: Vec<VarInfo>,
    slots: Vec<Slot>,
}

fn strip(prog: &ir::Program, ty: &Ty) -> Ty {
    let mut ty = ty.clone();
    for _ in 0..32 {
        let next = match &ty {
            Ty::Named(d) => match &prog.defs[*d].kind {
                DefKind::Alias(t) => t.clone(),
                DefKind::Subrange { base, .. } => Ty::Elem(*base),
                _ => break,
            },
            _ => break,
        };
        ty = next;
    }
    ty
}

fn kind_of(prog: &ir::Program, ty: &Ty) -> (Kind, String) {
    match strip(prog, ty) {
        Ty::Elem(e) => {
            let k = match e {
                Elem::Bool => Kind::Bool,
                Elem::Sint => Kind::Int(1),
                Elem::Int => Kind::Int(2),
                Elem::Dint => Kind::Int(4),
                Elem::Lint => Kind::Int(8),
                Elem::Usint | Elem::Byte => Kind::UInt(1),
                Elem::Uint | Elem::Word => Kind::UInt(2),
                Elem::Udint | Elem::Dword => Kind::UInt(4),
                Elem::Ulint | Elem::Lword => Kind::UInt(8),
                Elem::Real => Kind::Real,
                Elem::Lreal => Kind::LReal,
                _ => Kind::Other,
            };
            (k, e.name().to_string())
        }
        Ty::Named(d) => (Kind::Other, prog.defs[d].name.clone()),
        Ty::Str { wide, .. } => (Kind::Other, if wide { "WSTRING" } else { "STRING" }.into()),
        Ty::Array { .. } => (Kind::Other, "ARRAY".into()),
        _ => (Kind::Other, "?".into()),
    }
}

impl<'p> VmProgram<'p> {
    /// Instantiate `program` (or the only PROGRAM) of a compiled project.
    pub fn new(
        check: &'p CheckReport,
        program: Option<&str>,
        period_ns: i128,
    ) -> Result<VmProgram<'p>, String> {
        let prog = check
            .program
            .as_ref()
            .ok_or("the project does not compile; run rootplc check")?;
        let programs: Vec<usize> = (0..prog.defs.len())
            .filter(|&i| matches!(prog.pou(i), Some(p) if p.kind == PouKind::Program))
            .collect();
        let def = match program {
            Some(name) => prog
                .find(name)
                .filter(|i| programs.contains(i))
                .ok_or_else(|| format!("no PROGRAM named '{name}'"))?,
            None => match programs.as_slice() {
                [one] => *one,
                [] => return Err("the project has no PROGRAM".into()),
                _ => {
                    return Err(
                        "the project has several programs; choose one with --program".into(),
                    );
                }
            },
        };
        let mut vm = Vm::new(prog);
        let root = vm.instantiate(def);
        let mut vars = Vec::new();
        let mut slots = Vec::new();
        let mut add = |root: usize, def: usize, v: &ir::Var| {
            let (kind, type_name) = kind_of(prog, &v.ty);
            vars.push(VarInfo {
                name: v.name.clone(),
                kind,
                type_name,
                at: v.at.clone(),
                retain: v.retain,
            });
            slots.push(Slot {
                root,
                def,
                name: v.name.clone(),
                ty: v.ty.clone(),
            });
        };
        if let (Some(g), Some(groot)) = (prog.globals, vm.globals_root()) {
            for v in prog.pou(g).map(|p| p.vars.as_slice()).unwrap_or_default() {
                add(groot, g, v);
            }
        }
        for v in prog.pou(def).map(|p| p.vars.as_slice()).unwrap_or_default() {
            add(root, def, v);
        }
        Ok(VmProgram {
            vm,
            check,
            root,
            def,
            cycle: 0,
            period_ns,
            vars,
            slots,
        })
    }

    fn value(&self, i: usize) -> Option<&Value> {
        let s = self.slots.get(i)?;
        self.vm.read_var(s.root, s.def, &s.name)
    }
}

impl Program for VmProgram<'_> {
    fn vars(&self) -> &[VarInfo] {
        &self.vars
    }

    fn read(&self, i: usize) -> Option<Scalar> {
        let kind = self.vars.get(i)?.kind;
        match (kind, self.value(i)?) {
            (Kind::Bool, Value::Bool(b)) => Some(Scalar::Bool(*b)),
            (Kind::Int(_), Value::Int(n)) => Some(Scalar::Int(*n as i64)),
            (Kind::UInt(_), Value::Int(n)) => Some(Scalar::UInt(*n as u64)),
            (Kind::Real | Kind::LReal, Value::Real(x)) => Some(Scalar::Real(*x)),
            _ => None,
        }
    }

    fn text(&self, i: usize) -> String {
        match (self.value(i), self.slots.get(i)) {
            (Some(v), Some(s)) => self.vm.display(v, &s.ty),
            _ => String::new(),
        }
    }

    fn write(&mut self, i: usize, v: Scalar) -> bool {
        if self.vars.get(i).is_none_or(|x| x.kind == Kind::Other) {
            return false;
        }
        let value = match v {
            Scalar::Bool(b) => Value::Bool(b),
            Scalar::Int(n) => Value::Int(i128::from(n)),
            Scalar::UInt(n) => Value::Int(i128::from(n)),
            Scalar::Real(x) => Value::Real(x),
        };
        let s = &self.slots[i];
        let (root, def, name) = (s.root, s.def, s.name.clone());
        self.vm.write_var(root, def, &name, value)
    }

    fn cycle(&mut self, elapsed_ns: u64) -> Result<(), String> {
        self.vm.advance(i128::from(elapsed_ns));
        self.vm.begin_cycle(self.period_ns, self.cycle);
        self.cycle += 1;
        self.vm.cycle(self.root, self.def).map_err(|f| {
            let (file, line, col) = location(self.check, f.file, f.span.start);
            format!("{} at {file}:{line}:{col}: {}", f.kind.name(), f.message)
        })
    }
}

/// Run runtime v0 on a compiled project until `stop`, the requested cycles
/// or a fault ([runtime.cycle]).
pub fn run_runtime<D: IoDriver, C: Clock>(
    check: &CheckReport,
    program: Option<&str>,
    config: Config,
    io: D,
    clock: C,
    stop: &AtomicBool,
) -> Result<Report, String> {
    let p = VmProgram::new(check, program, i128::from(config.period_ns))?;
    let mut rt = Runtime::new(p, io, clock, config)?;
    Ok(rt.run(stop))
}

#[cfg(test)]
mod tests {
    use super::*;
    use rootplc_runtime::{NoIo, State, SystemClock};
    use std::path::PathBuf;

    fn check(src: &str) -> CheckReport {
        let c = crate::check_sources(vec![(PathBuf::from("plant.st"), src.to_string())]);
        assert!(c.ok(), "{:?}", c.files[0].diagnostics);
        c
    }

    const FILLER: &str = "PROGRAM Filler
VAR
    start AT %IX0.0 : BOOL;
    level AT %IW2 : INT;
    valve AT %QX0.0 : BOOL;
    shown AT %QW2 : INT;
    t : TON;
    done : BOOL;
END_VAR
VAR RETAIN
    batches : UDINT;
END_VAR
t(IN := start AND NOT done, PT := T#50ms);
valve := start AND NOT done AND level < 100;
IF t.Q AND NOT done THEN
    done := TRUE;
    batches := batches + 1;
END_IF;
shown := level * 2;
END_PROGRAM
";

    #[test]
    fn vm_program_runs_under_the_runtime() {
        let c = check(FILLER);
        let mut cfg = Config::with_period_ms(10);
        cfg.cycles = Some(8);
        let p = VmProgram::new(&c, None, 10_000_000).expect("program");
        let mut rt = Runtime::new(p, NoIo, SystemClock::default(), cfg).expect("binds");
        {
            let mut img = rt.image.lock().expect("image");
            img.input[0] = 1;
            img.input[2..4].copy_from_slice(&40i16.to_le_bytes());
        }
        let rep = rt.run(&AtomicBool::new(false));
        assert_eq!(rep.state, State::Stopped);
        let img = rt.image.lock().expect("image").clone();
        assert_eq!(i16::from_le_bytes([img.output[2], img.output[3]]), 80);
        // the 50 ms timer ran on real time: after 8 cycles of 10 ms the batch is done
        let v = |n: &str| {
            rep.vars
                .iter()
                .find(|v| v.name == n)
                .map(|v| v.value.clone())
        };
        assert_eq!(v("done").as_deref(), Some("TRUE"));
        assert_eq!(v("batches").as_deref(), Some("1"));
        assert_eq!(img.output[0] & 1, 0, "valve closes when done");
    }

    #[test]
    fn a_vm_fault_reports_its_place() {
        let c = check(
            "PROGRAM Div\nVAR q AT %QX0.0 : BOOL; d : INT; x : INT; END_VAR\nq := TRUE;\nx := 10 / d;\nEND_PROGRAM\n",
        );
        let mut cfg = Config::with_period_ms(1);
        cfg.cycles = Some(5);
        let rep = run_runtime(
            &c,
            None,
            cfg,
            NoIo,
            SystemClock::default(),
            &AtomicBool::new(false),
        )
        .expect("runs");
        assert!(
            matches!(&rep.state, State::Fault(f) if f.starts_with("DIV_BY_ZERO at plant.st:4")),
            "{:?}",
            rep.state
        );
    }
}
