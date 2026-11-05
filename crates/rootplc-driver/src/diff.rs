//! Differential verification ([diff.command] … [diff.limits]): run a unit
//! and a reference function block side by side with the same seeded
//! stimuli and compare their outputs every cycle.

use rootplc_sema::ir::{DefKind, PouKind, Section, Var};
use rootplc_sema::{Elem, Ty};
use rootplc_vm::{Value, Vm};

use crate::CheckReport;
use crate::json::location;

/// What to compare and how to drive it.
#[derive(Debug, Clone)]
pub struct DiffOptions {
    /// The reference function block.
    pub reference: String,
    /// The function block under comparison.
    pub unit: String,
    /// Cycles to run.
    pub cycles: u64,
    /// Virtual time per cycle, milliseconds.
    pub cycle_ms: u64,
    /// Seed of the stimulus sequence.
    pub seed: u64,
    /// Inputs held at a value: (name, ST literal).
    pub set: Vec<(String, String)>,
    /// Ranges of numeric inputs: (name, low, high).
    pub ranges: Vec<(String, f64, f64)>,
    /// Probability that an input changes in a cycle.
    pub toggle: f64,
    /// Largest allowed difference of REAL outputs.
    pub tolerance: f64,
}

impl Default for DiffOptions {
    fn default() -> Self {
        DiffOptions {
            reference: String::new(),
            unit: String::new(),
            cycles: 1000,
            cycle_ms: 10,
            seed: 1,
            set: Vec::new(),
            ranges: Vec::new(),
            toggle: 0.1,
            tolerance: 0.0001,
        }
    }
}

/// The outcome of a comparison ([diff.report]).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Verdict {
    /// No compared output differed in any cycle.
    Agree,
    /// At least one output differed.
    Differ,
    /// A block faulted at run time.
    Fault,
}

impl Verdict {
    /// The verdict as reported.
    pub fn name(self) -> &'static str {
        match self {
            Verdict::Agree => "agree",
            Verdict::Differ => "differ",
            Verdict::Fault => "fault",
        }
    }
}

/// One compared output.
#[derive(Debug, Clone)]
pub struct OutputResult {
    /// Output name (as in the reference).
    pub name: String,
    /// Cycles in which the unit's value differed.
    pub differing: u64,
}

/// The first difference, with the inputs that led to it.
#[derive(Debug, Clone)]
pub struct FirstDiff {
    /// Cycle number, from 1.
    pub cycle: u64,
    /// Output that differed.
    pub output: String,
    /// The reference's value.
    pub reference: String,
    /// The unit's value.
    pub unit: String,
    /// Driven inputs of this cycle and up to four before: (cycle, [(name, value)]).
    pub trace: Vec<(u64, Vec<(String, String)>)>,
}

/// Result of [`diff`].
#[derive(Debug, Clone)]
pub struct DiffReport {
    /// Reference block name.
    pub reference: String,
    /// Unit block name.
    pub unit: String,
    /// Verdict.
    pub verdict: Verdict,
    /// Cycles run.
    pub cycles: u64,
    /// Seed used.
    pub seed: u64,
    /// Inputs driven by the stimuli.
    pub driven: Vec<String>,
    /// Inputs held by `--set`, with their values.
    pub set: Vec<(String, String)>,
    /// Inputs of the reference kept at their initial value.
    pub held: Vec<String>,
    /// Compared outputs.
    pub outputs: Vec<OutputResult>,
    /// Reference inputs the unit lacks.
    pub missing_inputs: Vec<String>,
    /// Reference outputs the unit lacks.
    pub missing_outputs: Vec<String>,
    /// The first difference, if any.
    pub first: Option<FirstDiff>,
    /// The fault, if a block faulted: "<block>: <kind> at <file:line:col>: <message>".
    pub fault: Option<String>,
}

enum Drive {
    Bool,
    Int(f64, f64),
    Real(f64, f64),
}

struct Input {
    name: String,
    drive: Drive,
    ty: Ty,
    value: Value,
}

/// xorshift64*: a small, fixed pseudo-random sequence ([diff.stimuli]).
struct Rng(u64);

impl Rng {
    fn new(seed: u64) -> Rng {
        Rng(seed.wrapping_mul(0x9E37_79B9_7F4A_7C15) | 1)
    }
    fn next(&mut self) -> f64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        let r = x.wrapping_mul(0x2545_F491_4F6C_DD1D);
        (r >> 11) as f64 / (1u64 << 53) as f64
    }
}

fn strip<'a>(prog: &'a rootplc_sema::ir::Program, ty: &'a Ty) -> &'a Ty {
    let mut t = ty;
    for _ in 0..16 {
        match t {
            Ty::Named(d) => match &prog.defs[*d].kind {
                DefKind::Alias(inner) => t = inner,
                DefKind::Subrange { .. } => return t,
                _ => return t,
            },
            _ => return t,
        }
    }
    t
}

fn is_int(e: Elem) -> bool {
    use Elem::*;
    matches!(
        e,
        Sint | Int | Dint | Lint | Usint | Uint | Udint | Ulint | Byte | Word | Dword | Lword
    )
}

/// Nanoseconds of a duration literal (`T#1s500ms`, `TIME#2m`), or `None`.
fn parse_duration(text: &str) -> Option<i128> {
    let upper = text.to_ascii_uppercase();
    let body = upper
        .strip_prefix("TIME#")
        .or_else(|| upper.strip_prefix("T#"))
        .or_else(|| upper.strip_prefix("LTIME#"))
        .or_else(|| upper.strip_prefix("LT#"))?;
    let (neg, body) = match body.strip_prefix('-') {
        Some(b) => (true, b),
        None => (false, body),
    };
    let body: String = body.chars().filter(|c| *c != '_').collect();
    let mut total: f64 = 0.0;
    let mut rest = body.as_str();
    if rest.is_empty() {
        return None;
    }
    while !rest.is_empty() {
        let num_len = rest
            .find(|c: char| !(c.is_ascii_digit() || c == '.'))
            .unwrap_or(rest.len());
        if num_len == 0 {
            return None;
        }
        let n: f64 = rest[..num_len].parse().ok()?;
        rest = &rest[num_len..];
        let unit_len = rest
            .find(|c: char| c.is_ascii_digit() || c == '.')
            .unwrap_or(rest.len());
        let factor = match &rest[..unit_len] {
            "D" => 86_400e9,
            "H" => 3_600e9,
            "M" => 60e9,
            "S" => 1e9,
            "MS" => 1e6,
            "US" => 1e3,
            "NS" => 1.0,
            _ => return None,
        };
        rest = &rest[unit_len..];
        total += n * factor;
    }
    let ns = total.round() as i128;
    Some(if neg { -ns } else { ns })
}

/// The value of a `--set` literal ([diff.stimuli]).
fn parse_value(prog: &rootplc_sema::ir::Program, text: &str) -> Result<Value, String> {
    let t = text.trim();
    if t.eq_ignore_ascii_case("TRUE") {
        return Ok(Value::Bool(true));
    }
    if t.eq_ignore_ascii_case("FALSE") {
        return Ok(Value::Bool(false));
    }
    if let Some(ns) = parse_duration(t) {
        return Ok(Value::Int(ns));
    }
    if let Some((ty, name)) = t.split_once('#') {
        if let Some(d) = prog.find(ty) {
            if let DefKind::Enum(values) = &prog.defs[d].kind {
                if let Some((_, v)) = values.iter().find(|(n, _)| n.eq_ignore_ascii_case(name)) {
                    return Ok(Value::Int(*v));
                }
                return Err(format!("{ty} has no value {name}"));
            }
        }
        return Err(format!("cannot read the value '{t}'"));
    }
    let digits: String = t.chars().filter(|c| *c != '_').collect();
    if let Ok(n) = digits.parse::<i128>() {
        return Ok(Value::Int(n));
    }
    if let Ok(x) = digits.parse::<f64>() {
        return Ok(Value::Real(x));
    }
    Err(format!("cannot read the value '{t}'"))
}

fn function_block(prog: &rootplc_sema::ir::Program, name: &str) -> Result<usize, String> {
    let d = prog
        .find(name)
        .ok_or_else(|| format!("no FUNCTION_BLOCK named '{name}'"))?;
    match prog.pou(d) {
        Some(p) if p.kind == PouKind::FunctionBlock => {}
        _ => return Err(format!("'{name}' is not a FUNCTION_BLOCK")),
    }
    let p = prog.pou(d).expect("checked above");
    if p.vars.iter().any(|v| v.section == Section::InOut) {
        return Err(format!(
            "'{name}' has VAR_IN_OUT, which rootplc diff cannot drive"
        ));
    }
    Ok(d)
}

fn vars(prog: &rootplc_sema::ir::Program, def: usize, section: Section) -> Vec<Var> {
    prog.pou(def)
        .map(|p| {
            p.vars
                .iter()
                .filter(|v| v.section == section)
                .cloned()
                .collect()
        })
        .unwrap_or_default()
}

fn has(list: &[Var], name: &str) -> bool {
    list.iter().any(|v| v.name.eq_ignore_ascii_case(name))
}

fn same(a: &Value, b: &Value, tolerance: f64) -> bool {
    match (a, b) {
        (Value::Bool(x), Value::Bool(y)) => x == y,
        (Value::Int(x), Value::Int(y)) => x == y,
        (Value::Real(x), Value::Real(y)) => (x - y).abs() <= tolerance,
        (Value::Real(x), Value::Int(y)) | (Value::Int(y), Value::Real(x)) => {
            (x - *y as f64).abs() <= tolerance
        }
        (x, y) => x == y,
    }
}

/// Compare `opt.unit` with `opt.reference` on a compiled project.
pub fn diff(check: &CheckReport, opt: &DiffOptions) -> Result<DiffReport, String> {
    let prog = check
        .program
        .as_ref()
        .ok_or("the project does not compile; run rootplc check")?;
    let rdef = function_block(prog, &opt.reference)?;
    let udef = function_block(prog, &opt.unit)?;
    let r_in = vars(prog, rdef, Section::Input);
    let u_in = vars(prog, udef, Section::Input);
    let r_out = vars(prog, rdef, Section::Output);
    let u_out = vars(prog, udef, Section::Output);

    for (name, _) in &opt.set {
        if !has(&r_in, name) {
            return Err(format!("--set {name}: not an input of {}", opt.reference));
        }
    }
    for (name, lo, hi) in &opt.ranges {
        if !has(&r_in, name) {
            return Err(format!("--range {name}: not an input of {}", opt.reference));
        }
        if lo > hi {
            return Err(format!("--range {name}: {lo} is above {hi}"));
        }
    }

    let mut vm = Vm::new(prog);
    let rroot = vm.instantiate(rdef);
    let uroot = vm.instantiate(udef);

    let mut report = DiffReport {
        reference: opt.reference.clone(),
        unit: opt.unit.clone(),
        verdict: Verdict::Agree,
        cycles: 0,
        seed: opt.seed,
        driven: Vec::new(),
        set: Vec::new(),
        held: Vec::new(),
        outputs: Vec::new(),
        missing_inputs: Vec::new(),
        missing_outputs: Vec::new(),
        first: None,
        fault: None,
    };

    // inputs: set, driven, held or missing ([diff.interface], [diff.stimuli])
    let mut inputs: Vec<Input> = Vec::new();
    for v in &r_in {
        // a set input configures the reference even when the unit lacks it
        if let Some((_, text)) = opt
            .set
            .iter()
            .find(|(n, _)| n.eq_ignore_ascii_case(&v.name))
        {
            let value = parse_value(prog, text).map_err(|e| format!("--set {}: {e}", v.name))?;
            let in_unit = has(&u_in, &v.name);
            if !vm.write_var(rroot, rdef, &v.name, value.clone())
                || (in_unit && !vm.write_var(uroot, udef, &v.name, value))
            {
                return Err(format!("--set {}: the value does not fit", v.name));
            }
            report.set.push((v.name.clone(), text.trim().to_string()));
            continue;
        }
        if !has(&u_in, &v.name) {
            report.missing_inputs.push(v.name.clone());
            continue;
        }
        let range = opt
            .ranges
            .iter()
            .find(|(n, _, _)| n.eq_ignore_ascii_case(&v.name))
            .map(|(_, lo, hi)| (*lo, *hi))
            .unwrap_or((0.0, 100.0));
        let drive = match strip(prog, &v.ty) {
            Ty::Elem(Elem::Bool) => Some(Drive::Bool),
            Ty::Elem(e) if is_int(*e) => Some(Drive::Int(range.0, range.1)),
            Ty::Elem(Elem::Real | Elem::Lreal) => Some(Drive::Real(range.0, range.1)),
            _ => None,
        };
        match drive {
            Some(drive) => {
                let value = vm
                    .read_var(rroot, rdef, &v.name)
                    .cloned()
                    .unwrap_or(Value::Bool(false));
                report.driven.push(v.name.clone());
                inputs.push(Input {
                    name: v.name.clone(),
                    drive,
                    ty: v.ty.clone(),
                    value,
                });
            }
            None => report.held.push(v.name.clone()),
        }
    }
    let mut compared: Vec<Var> = Vec::new();
    for v in &r_out {
        if has(&u_out, &v.name) {
            compared.push(v.clone());
            report.outputs.push(OutputResult {
                name: v.name.clone(),
                differing: 0,
            });
        } else {
            report.missing_outputs.push(v.name.clone());
        }
    }

    let mut rng = Rng::new(opt.seed);
    let cycle_ns = i128::from(opt.cycle_ms) * 1_000_000;
    let mut trace: Vec<(u64, Vec<(String, String)>)> = Vec::new();
    for c in 1..=opt.cycles {
        vm.advance(cycle_ns);
        for inp in &mut inputs {
            let change = rng.next() < opt.toggle;
            let pick = rng.next();
            if !change {
                continue;
            }
            inp.value = match inp.drive {
                Drive::Bool => Value::Bool(!matches!(inp.value, Value::Bool(true))),
                Drive::Int(lo, hi) => {
                    let (lo, hi) = (lo.ceil(), hi.floor());
                    let span = (hi - lo + 1.0).max(1.0);
                    Value::Int((lo + (pick * span).floor()).min(hi.max(lo)) as i128)
                }
                Drive::Real(lo, hi) => Value::Real(lo + pick * (hi - lo)),
            };
        }
        let mut row = Vec::new();
        for inp in &inputs {
            vm.write_var(rroot, rdef, &inp.name, inp.value.clone());
            vm.write_var(uroot, udef, &inp.name, inp.value.clone());
            row.push((inp.name.clone(), vm.display(&inp.value, &inp.ty)));
        }
        trace.push((c, row));
        if trace.len() > 5 {
            trace.remove(0);
        }
        for (root, def, name) in [(rroot, rdef, &opt.reference), (uroot, udef, &opt.unit)] {
            if let Err(f) = vm.cycle(root, def) {
                let (file, line, col) = location(check, f.file, f.span.start);
                report.fault = Some(format!(
                    "{name}: {} at {file}:{line}:{col}: {} (cycle {c})",
                    f.kind.name(),
                    f.message
                ));
                report.verdict = Verdict::Fault;
                report.cycles = c;
                return Ok(report);
            }
        }
        report.cycles = c;
        for (k, v) in compared.iter().enumerate() {
            let a = vm.read_var(rroot, rdef, &v.name).cloned();
            let b = vm.read_var(uroot, udef, &v.name).cloned();
            let (Some(a), Some(b)) = (a, b) else { continue };
            if same(&a, &b, opt.tolerance) {
                continue;
            }
            report.outputs[k].differing += 1;
            report.verdict = Verdict::Differ;
            if report.first.is_none() {
                let uty = vars(prog, udef, Section::Output)
                    .into_iter()
                    .find(|x| x.name.eq_ignore_ascii_case(&v.name))
                    .map(|x| x.ty)
                    .unwrap_or_else(|| v.ty.clone());
                report.first = Some(FirstDiff {
                    cycle: c,
                    output: v.name.clone(),
                    reference: vm.display(&a, &v.ty),
                    unit: vm.display(&b, &uty),
                    trace: trace.clone(),
                });
            }
        }
    }
    Ok(report)
}

/// The report as text ([diff.report]).
pub fn render(r: &DiffReport) -> String {
    let mut s = format!(
        "diff {} against {}: {} ({} cycles, seed {})\n",
        r.unit,
        r.reference,
        r.verdict.name(),
        r.cycles,
        r.seed
    );
    let list = |v: &[String]| {
        if v.is_empty() {
            "-".to_string()
        } else {
            v.join(", ")
        }
    };
    s += &format!("  driven: {}\n", list(&r.driven));
    if !r.set.is_empty() {
        let set: Vec<String> = r.set.iter().map(|(n, v)| format!("{n}={v}")).collect();
        s += &format!("  set: {}\n", set.join(", "));
    }
    if !r.held.is_empty() {
        s += &format!("  held at their initial value: {}\n", list(&r.held));
    }
    if !r.missing_inputs.is_empty() {
        s += &format!("  inputs {} lacks: {}\n", r.unit, list(&r.missing_inputs));
    }
    if !r.missing_outputs.is_empty() {
        s += &format!(
            "  outputs {} lacks (not compared): {}\n",
            r.unit,
            list(&r.missing_outputs)
        );
    }
    for o in &r.outputs {
        s += &format!(
            "  {}: {}\n",
            o.name,
            if o.differing == 0 {
                "same in every cycle".to_string()
            } else {
                format!("differs in {} of {} cycles", o.differing, r.cycles)
            }
        );
    }
    if let Some(f) = &r.first {
        s += &format!(
            "first difference: cycle {}, {}: {} = {}, {} = {}\n",
            f.cycle, f.output, r.reference, f.reference, r.unit, f.unit
        );
        for (c, row) in &f.trace {
            let vals: Vec<String> = row.iter().map(|(n, v)| format!("{n}={v}")).collect();
            s += &format!("  cycle {c}: {}\n", vals.join(", "));
        }
    }
    if let Some(f) = &r.fault {
        s += &format!("fault: {f}\n");
    }
    if r.verdict == Verdict::Agree {
        s += "agreement covers the sampled cycles only ([diff.limits])\n";
    }
    s
}

fn jstr(s: &str) -> String {
    rootplc_diag::json_string(s)
}

/// The report as one JSON object ([diff.report]).
pub fn to_json(r: &DiffReport) -> String {
    let arr = |v: &[String]| {
        format!(
            "[{}]",
            v.iter().map(|x| jstr(x)).collect::<Vec<_>>().join(",")
        )
    };
    let set = r
        .set
        .iter()
        .map(|(n, v)| format!("{{\"name\":{},\"value\":{}}}", jstr(n), jstr(v)))
        .collect::<Vec<_>>()
        .join(",");
    let outputs = r
        .outputs
        .iter()
        .map(|o| {
            format!(
                "{{\"name\":{},\"differing\":{}}}",
                jstr(&o.name),
                o.differing
            )
        })
        .collect::<Vec<_>>()
        .join(",");
    let first = match &r.first {
        None => "null".to_string(),
        Some(f) => {
            let trace = f
                .trace
                .iter()
                .map(|(c, row)| {
                    let vals = row
                        .iter()
                        .map(|(n, v)| format!("{}:{}", jstr(n), jstr(v)))
                        .collect::<Vec<_>>()
                        .join(",");
                    format!("{{\"cycle\":{c},\"inputs\":{{{vals}}}}}")
                })
                .collect::<Vec<_>>()
                .join(",");
            format!(
                "{{\"cycle\":{},\"output\":{},\"reference\":{},\"unit\":{},\"trace\":[{trace}]}}",
                f.cycle,
                jstr(&f.output),
                jstr(&f.reference),
                jstr(&f.unit)
            )
        }
    };
    let fault = r
        .fault
        .as_deref()
        .map(jstr)
        .unwrap_or_else(|| "null".into());
    format!(
        "{{\"command\":\"diff\",\"ok\":{},\"reference\":{},\"unit\":{},\"verdict\":{},\"cycles\":{},\"seed\":{},\"driven\":{},\"set\":[{set}],\"held\":{},\"missing_inputs\":{},\"missing_outputs\":{},\"outputs\":[{outputs}],\"first\":{first},\"fault\":{fault}}}",
        r.verdict == Verdict::Agree,
        jstr(&r.reference),
        jstr(&r.unit),
        jstr(r.verdict.name()),
        r.cycles,
        r.seed,
        arr(&r.driven),
        arr(&r.held),
        arr(&r.missing_inputs),
        arr(&r.missing_outputs),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn durations() {
        assert_eq!(parse_duration("T#1s500ms"), Some(1_500_000_000));
        assert_eq!(parse_duration("TIME#2m"), Some(120_000_000_000));
        assert_eq!(parse_duration("t#1h_30m"), Some(5_400_000_000_000));
        assert_eq!(parse_duration("T#-250ms"), Some(-250_000_000));
        assert_eq!(parse_duration("T#1.5s"), Some(1_500_000_000));
        assert_eq!(parse_duration("T#"), None);
        assert_eq!(parse_duration("T#5x"), None);
        assert_eq!(parse_duration("5s"), None);
    }

    #[test]
    fn rng_is_repeatable_and_in_range() {
        let mut a = Rng::new(7);
        let mut b = Rng::new(7);
        for _ in 0..1000 {
            let x = a.next();
            assert!((0.0..1.0).contains(&x));
            assert_eq!(x, b.next());
        }
        assert_ne!(Rng::new(1).next(), Rng::new(2).next());
    }

    #[test]
    fn comparing_values() {
        assert!(same(&Value::Real(1.0), &Value::Real(1.00005), 0.0001));
        assert!(!same(&Value::Real(1.0), &Value::Real(1.001), 0.0001));
        assert!(same(&Value::Int(3), &Value::Real(3.0), 0.0001));
        assert!(!same(&Value::Bool(true), &Value::Bool(false), 0.0001));
        assert!(same(&Value::Int(5), &Value::Int(5), 0.0));
    }
}
