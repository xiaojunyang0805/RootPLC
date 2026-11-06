//! `rootplc sim`: programs run as one task on the virtual clock, driven by
//! a scenario, with expectations, a CSV trace and comparison with an
//! earlier trace (spec/17-simulation.md).

use std::path::PathBuf;

use rootplc_diag::json_string;
use rootplc_sema::Ty;
use rootplc_sema::ir::PouKind;
use rootplc_vm::{Fault, Loc, Value, Vm};

use crate::CheckReport;
use crate::diff::{parse_duration, parse_value};

/// Comparison of an expectation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Op {
    /// `=`
    Eq,
    /// `<>`
    Ne,
    /// `<`
    Lt,
    /// `<=`
    Le,
    /// `>`
    Gt,
    /// `>=`
    Ge,
}

/// `at T set PATH := VALUE`.
#[derive(Debug, Clone)]
pub struct SetLine {
    /// Line in the scenario (1-based).
    pub line: usize,
    /// Time, ns.
    pub at: i128,
    /// Variable path.
    pub path: String,
    /// Value as written.
    pub value: String,
}

/// `at T expect ...` or `from T1 to T2 expect ...`.
#[derive(Debug, Clone)]
pub struct ExpectLine {
    /// Line in the scenario (1-based).
    pub line: usize,
    /// The line as written.
    pub text: String,
    /// Start time, ns.
    pub from: i128,
    /// End time for an interval, ns.
    pub to: Option<i128>,
    /// Variable path.
    pub path: String,
    /// Comparison.
    pub op: Op,
    /// Value as written.
    pub value: String,
    /// Tolerance for REAL comparisons.
    pub within: f64,
}

/// A parsed scenario ([sim.scenario]).
#[derive(Debug, Clone, Default)]
pub struct Scenario {
    /// Programs in task order.
    pub programs: Vec<String>,
    /// Virtual time per cycle, ns.
    pub cycle: i128,
    /// Run time, ns.
    pub duration: i128,
    /// Recorded paths.
    pub record: Vec<String>,
    /// Values to set.
    pub sets: Vec<SetLine>,
    /// Expectations.
    pub expects: Vec<ExpectLine>,
}

fn duration(text: &str, line: usize) -> Result<i128, String> {
    parse_duration(text.trim())
        .ok_or_else(|| format!("scenario line {line}: '{}' is not a duration", text.trim()))
}

/// Split `PATH OP VALUE [within X]`.
fn condition(text: &str, line: usize) -> Result<(String, Op, String, f64), String> {
    let (body, within) = match text.to_ascii_lowercase().rfind(" within ") {
        Some(k) => {
            let w = text[k + 8..].trim();
            let w = w
                .parse::<f64>()
                .map_err(|_| format!("scenario line {line}: 'within {w}' is not a number"))?;
            (&text[..k], w)
        }
        None => (text, 0.0001),
    };
    for (sym, op) in [
        ("<>", Op::Ne),
        ("<=", Op::Le),
        (">=", Op::Ge),
        ("=", Op::Eq),
        ("<", Op::Lt),
        (">", Op::Gt),
    ] {
        if let Some(k) = body.find(sym) {
            let path = body[..k].trim();
            let value = body[k + sym.len()..].trim();
            if path.is_empty() || value.is_empty() {
                break;
            }
            return Ok((path.to_string(), op, value.to_string(), within));
        }
    }
    Err(format!(
        "scenario line {line}: write PATH OP VALUE with OP one of = <> < <= > >="
    ))
}

/// Parse a scenario text ([sim.scenario]).
pub fn parse_scenario(text: &str) -> Result<Scenario, String> {
    let mut s = Scenario {
        cycle: 10_000_000,
        ..Scenario::default()
    };
    let mut have_duration = false;
    for (k, raw) in text.lines().enumerate() {
        let line = k + 1;
        let t = match raw.find('#') {
            // a comment starts with # at the beginning or after a space;
            // T#1s and Type#Value contain # too
            Some(0) => "",
            Some(_) => raw
                .match_indices(" #")
                .next()
                .map_or(raw, |(i, _)| &raw[..i]),
            None => raw,
        }
        .trim();
        if t.is_empty() {
            continue;
        }
        let (word, rest) = t.split_once(char::is_whitespace).unwrap_or((t, ""));
        let rest = rest.trim();
        match word.to_ascii_lowercase().as_str() {
            "programs" => s.programs = rest.split_whitespace().map(String::from).collect(),
            "cycle" => s.cycle = duration(rest, line)?,
            "duration" => {
                s.duration = duration(rest, line)?;
                have_duration = true;
            }
            "record" => s.record.extend(rest.split_whitespace().map(String::from)),
            "at" => {
                let (time, after) = rest.split_once(char::is_whitespace).ok_or_else(|| {
                    format!("scenario line {line}: write 'at T set ...' or 'at T expect ...'")
                })?;
                let at = duration(time, line)?;
                let after = after.trim();
                let (verb, body) = after.split_once(char::is_whitespace).unwrap_or((after, ""));
                match verb.to_ascii_lowercase().as_str() {
                    "set" => {
                        let (path, value) = body.split_once(":=").ok_or_else(|| {
                            format!("scenario line {line}: write 'set PATH := VALUE'")
                        })?;
                        s.sets.push(SetLine {
                            line,
                            at,
                            path: path.trim().to_string(),
                            value: value.trim().to_string(),
                        });
                    }
                    "expect" => {
                        let (path, op, value, within) = condition(body, line)?;
                        s.expects.push(ExpectLine {
                            line,
                            text: t.to_string(),
                            from: at,
                            to: None,
                            path,
                            op,
                            value,
                            within,
                        });
                    }
                    _ => {
                        return Err(format!(
                            "scenario line {line}: after 'at T' write 'set' or 'expect'"
                        ));
                    }
                }
            }
            "from" => {
                let parts: Vec<&str> = rest.splitn(4, char::is_whitespace).collect();
                let ok = parts.len() == 4
                    && parts[1].eq_ignore_ascii_case("to")
                    && parts[3]
                        .split_whitespace()
                        .next()
                        .is_some_and(|w| w.eq_ignore_ascii_case("expect"));
                if !ok {
                    return Err(format!(
                        "scenario line {line}: write 'from T1 to T2 expect PATH OP VALUE'"
                    ));
                }
                let (from, to) = (duration(parts[0], line)?, duration(parts[2], line)?);
                let body = parts[3].trim_start()[6..].trim();
                let (path, op, value, within) = condition(body, line)?;
                s.expects.push(ExpectLine {
                    line,
                    text: t.to_string(),
                    from,
                    to: Some(to),
                    path,
                    op,
                    value,
                    within,
                });
            }
            _ => return Err(format!("scenario line {line}: unknown statement '{word}'")),
        }
    }
    if s.programs.is_empty() {
        return Err("scenario: 'programs' is missing".into());
    }
    if !have_duration {
        return Err("scenario: 'duration' is missing".into());
    }
    if s.cycle <= 0 {
        return Err("scenario: 'cycle' must be more than 0".into());
    }
    Ok(s)
}

/// Result of one expectation.
#[derive(Debug, Clone)]
pub struct ExpectResult {
    /// The expectation.
    pub expect: ExpectLine,
    /// It was checked at least once.
    pub checked: bool,
    /// It held every time it was checked.
    pub ok: bool,
    /// First failing cycle, its start time (ms) and the value seen.
    pub failed: Option<(u64, i128, String)>,
}

/// First difference between a run and a trace ([sim.compare]).
#[derive(Debug, Clone, PartialEq)]
pub struct TraceDiff {
    /// Cycle.
    pub cycle: u64,
    /// Start time, ms.
    pub time_ms: i128,
    /// Path.
    pub path: String,
    /// Value in the trace.
    pub trace: String,
    /// Value in the run.
    pub run: String,
}

/// Comparison of a run with a trace.
#[derive(Debug, Clone, Default)]
pub struct Compare {
    /// First differing value.
    pub first: Option<TraceDiff>,
    /// Paths only in the trace.
    pub only_trace: Vec<String>,
    /// Paths only in the run.
    pub only_run: Vec<String>,
    /// Cycles in the trace and in the run.
    pub cycles: (usize, usize),
}

impl Compare {
    /// Same values in every compared cycle and the same number of cycles.
    pub fn equal(&self) -> bool {
        self.first.is_none() && self.cycles.0 == self.cycles.1
    }
}

/// Recorded values: one row per cycle (cycle, time ms, values).
#[derive(Debug, Clone, Default)]
pub struct Trace {
    /// Recorded paths.
    pub paths: Vec<String>,
    /// Rows.
    pub rows: Vec<(u64, i128, Vec<String>)>,
}

/// Report of `rootplc sim`.
#[derive(Debug, Clone)]
pub struct SimReport {
    /// Compilation result.
    pub check: CheckReport,
    /// Programs run.
    pub programs: Vec<String>,
    /// Cycle time, ns.
    pub cycle: i128,
    /// Cycles run.
    pub cycles: u64,
    /// Fault that stopped the run, with its cycle.
    pub fault: Option<(u64, Fault)>,
    /// Every expectation.
    pub expectations: Vec<ExpectResult>,
    /// The trace.
    pub trace: Trace,
    /// Comparison with an earlier trace.
    pub compare: Option<Compare>,
}

impl SimReport {
    /// No fault, every expectation held, the compared trace matches.
    pub fn ok(&self) -> bool {
        self.fault.is_none()
            && self.expectations.iter().all(|e| e.checked && e.ok)
            && self.compare.as_ref().is_none_or(Compare::equal)
    }
}

/// Outcome of [`sim_sources`].
#[derive(Debug)]
pub enum SimRun {
    /// The scenario ran.
    Report(Box<SimReport>),
    /// The project does not compile.
    NotCompiling(Box<CheckReport>),
}

fn holds(op: Op, a: &Value, b: &Value, within: f64) -> Option<bool> {
    use std::cmp::Ordering;
    let ord = match (a, b) {
        (Value::Real(_), _) | (_, Value::Real(_)) => {
            let (x, y) = (num(a)?, num(b)?);
            if matches!(op, Op::Eq | Op::Ne) {
                let eq = (x - y).abs() <= within;
                return Some(eq == (op == Op::Eq));
            }
            x.partial_cmp(&y)?
        }
        (Value::Int(x), Value::Int(y)) => x.cmp(y),
        (Value::Bool(x), Value::Bool(y)) => x.cmp(y),
        (Value::Str(x), Value::Str(y)) => x.cmp(y),
        _ => return None,
    };
    Some(match op {
        Op::Eq => ord == Ordering::Equal,
        Op::Ne => ord != Ordering::Equal,
        Op::Lt => ord == Ordering::Less,
        Op::Le => ord != Ordering::Greater,
        Op::Gt => ord == Ordering::Greater,
        Op::Ge => ord != Ordering::Less,
    })
}

fn num(v: &Value) -> Option<f64> {
    match v {
        Value::Real(x) => Some(*x),
        Value::Int(i) => Some(*i as f64),
        _ => None,
    }
}

/// Quote a CSV field when needed (RFC 4180).
fn csv_field(s: &str) -> String {
    if s.contains([',', '"', '\n']) {
        format!("\"{}\"", s.replace('"', "\"\""))
    } else {
        s.to_string()
    }
}

/// The trace as CSV text ([sim.trace]).
pub fn trace_csv(t: &Trace) -> String {
    let mut out = String::from("cycle,time_ms");
    for p in &t.paths {
        out.push(',');
        out.push_str(&csv_field(p));
    }
    out.push('\n');
    for (c, ms, vals) in &t.rows {
        out.push_str(&format!("{c},{ms}"));
        for v in vals {
            out.push(',');
            out.push_str(&csv_field(v));
        }
        out.push('\n');
    }
    out
}

fn csv_line(line: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut quoted = false;
    let mut chars = line.chars().peekable();
    while let Some(c) = chars.next() {
        match (c, quoted) {
            ('"', true) if chars.peek() == Some(&'"') => {
                cur.push('"');
                chars.next();
            }
            ('"', _) => quoted = !quoted,
            (',', false) => out.push(std::mem::take(&mut cur)),
            _ => cur.push(c),
        }
    }
    out.push(cur);
    out
}

/// Read a CSV trace written by [`trace_csv`].
pub fn read_trace(text: &str) -> Result<Trace, String> {
    let mut lines = text.lines().filter(|l| !l.trim().is_empty());
    let header = csv_line(lines.next().ok_or("trace: empty file")?);
    if header.len() < 2 || header[0] != "cycle" || header[1] != "time_ms" {
        return Err("trace: the header must start with cycle,time_ms".into());
    }
    let mut t = Trace {
        paths: header[2..].to_vec(),
        rows: Vec::new(),
    };
    for (k, l) in lines.enumerate() {
        let f = csv_line(l);
        if f.len() != header.len() {
            return Err(format!(
                "trace row {}: {} fields, expected {}",
                k + 1,
                f.len(),
                header.len()
            ));
        }
        let c = f[0]
            .parse()
            .map_err(|_| format!("trace row {}: cycle", k + 1))?;
        let ms = f[1]
            .parse()
            .map_err(|_| format!("trace row {}: time_ms", k + 1))?;
        t.rows.push((c, ms, f[2..].to_vec()));
    }
    Ok(t)
}

fn same_value(a: &str, b: &str) -> bool {
    if a == b {
        return true;
    }
    let real = |s: &str| s.contains(['.', 'e', 'E']);
    match (a.parse::<f64>(), b.parse::<f64>()) {
        (Ok(x), Ok(y)) if real(a) || real(b) => {
            let scale = x.abs().max(y.abs()).max(1.0);
            (x - y).abs() <= 0.0001 * scale
        }
        _ => false,
    }
}

/// Compare a run's trace with an earlier trace ([sim.compare]).
pub fn compare(old: &Trace, new: &Trace) -> Compare {
    let pos = |t: &Trace, p: &str| t.paths.iter().position(|x| x.eq_ignore_ascii_case(p));
    let common: Vec<(String, usize, usize)> = new
        .paths
        .iter()
        .filter_map(|p| Some((p.clone(), pos(old, p)?, pos(new, p)?)))
        .collect();
    let mut c = Compare {
        cycles: (old.rows.len(), new.rows.len()),
        only_trace: old
            .paths
            .iter()
            .filter(|p| pos(new, p).is_none())
            .cloned()
            .collect(),
        only_run: new
            .paths
            .iter()
            .filter(|p| pos(old, p).is_none())
            .cloned()
            .collect(),
        first: None,
    };
    'rows: for (a, b) in old.rows.iter().zip(&new.rows) {
        for (p, i, j) in &common {
            if !same_value(&a.2[*i], &b.2[*j]) {
                c.first = Some(TraceDiff {
                    cycle: b.0,
                    time_ms: b.1,
                    path: p.clone(),
                    trace: a.2[*i].clone(),
                    run: b.2[*j].clone(),
                });
                break 'rows;
            }
        }
    }
    c
}

/// Run a scenario on sources ([sim.command]). `compare_with` is the text of
/// an earlier trace. Errors in the scenario or its paths are `Err`.
pub fn sim_sources(
    sources: Vec<(PathBuf, String)>,
    libraries: &[String],
    scenario: &str,
    compare_with: Option<&str>,
) -> Result<SimRun, String> {
    let sc = parse_scenario(scenario)?;
    let old = compare_with.map(read_trace).transpose()?;
    let check = crate::check_sources_with(sources, libraries)?;
    if !check.ok() {
        return Ok(SimRun::NotCompiling(Box::new(check)));
    }
    let report = run(check, &sc, old.as_ref())?;
    Ok(SimRun::Report(Box::new(report)))
}

fn run(check: CheckReport, sc: &Scenario, old: Option<&Trace>) -> Result<SimReport, String> {
    let prog = check.program.as_ref().ok_or("nothing to simulate")?;
    let mut defs = Vec::new();
    for name in &sc.programs {
        let d = prog
            .find(name)
            .filter(|&d| prog.pou(d).is_some_and(|p| p.kind == PouKind::Program))
            .ok_or_else(|| format!("scenario: no PROGRAM named '{name}'"))?;
        defs.push((prog.defs[d].name.clone(), d));
    }
    let mut vm = Vm::new(prog);
    let roots: Vec<(String, usize, usize)> = defs
        .iter()
        .map(|(n, d)| (n.clone(), *d, vm.instantiate(*d)))
        .collect();
    let locate = |vm: &Vm, path: &str| -> Result<(Loc, Ty), String> {
        if let Some((first, rest)) = path.split_once('.') {
            if let Some((_, d, r)) = roots.iter().find(|(n, _, _)| n.eq_ignore_ascii_case(first)) {
                return vm
                    .locate(*r, *d, rest)
                    .map_err(|e| format!("scenario: {path}: {e}"));
            }
        }
        vm.locate_global(path)
            .map_err(|e| format!("scenario: {path}: {e}"))
    };
    let mut sets = Vec::new();
    for s in &sc.sets {
        let (loc, ty) = locate(&vm, &s.path).map_err(|e| format!("line {}: {e}", s.line))?;
        let v = parse_value(prog, &s.value, &ty)
            .map_err(|e| format!("scenario line {}: {e}", s.line))?;
        sets.push((s.at, loc, ty, v));
    }
    let mut expects = Vec::new();
    for e in &sc.expects {
        let (loc, ty) = locate(&vm, &e.path).map_err(|x| format!("line {}: {x}", e.line))?;
        let v = parse_value(prog, &e.value, &ty)
            .map_err(|x| format!("scenario line {}: {x}", e.line))?;
        expects.push((loc, ty, v));
    }
    let mut recorded = Vec::new();
    for p in &sc.record {
        recorded.push(locate(&vm, p)?);
    }
    let n = (sc.duration / sc.cycle).max(1) as u64;
    let mut applied = vec![false; sets.len()];
    let mut results: Vec<ExpectResult> = sc
        .expects
        .iter()
        .map(|e| ExpectResult {
            expect: e.clone(),
            checked: false,
            ok: true,
            failed: None,
        })
        .collect();
    let mut trace = Trace {
        paths: sc.record.clone(),
        rows: Vec::new(),
    };
    let mut fault = None;
    let mut done = 0;
    let check_one = |vm: &Vm, k: usize, cycle: u64, ms: i128, results: &mut Vec<ExpectResult>| {
        let (loc, ty, want) = &expects[k];
        let got = vm.value_at(loc).cloned();
        let r = &mut results[k];
        r.checked = true;
        let ok = got
            .as_ref()
            .and_then(|g| holds(r.expect.op, g, want, r.expect.within))
            .unwrap_or(false);
        if !ok && r.failed.is_none() {
            r.ok = false;
            let shown = got.map_or("?".to_string(), |g| vm.display(&g, ty));
            r.failed = Some((cycle, ms, shown));
        }
    };
    for k in 0..n {
        let t = i128::from(k) * sc.cycle;
        for (i, (at, loc, ty, v)) in sets.iter().enumerate() {
            if !applied[i] && *at <= t {
                applied[i] = true;
                if !vm.set_at(loc, v.clone(), ty) {
                    return Err(format!(
                        "scenario line {}: the value does not fit {}",
                        sc.sets[i].line, sc.sets[i].path
                    ));
                }
            }
        }
        vm.begin_cycle(sc.cycle, k);
        for (_, d, r) in &roots {
            if let Err(f) = vm.cycle(*r, *d) {
                fault = Some((k, f));
                break;
            }
        }
        if fault.is_some() {
            break;
        }
        done = k + 1;
        let ms = t / 1_000_000;
        for i in 0..expects.len() {
            let e = &sc.expects[i];
            let due = match e.to {
                None => !results[i].checked && e.from <= t,
                Some(to) => e.from <= t && t <= to,
            };
            if due {
                check_one(&vm, i, k, ms, &mut results);
            }
        }
        let row = recorded
            .iter()
            .map(|(loc, ty)| {
                vm.value_at(loc)
                    .map_or("?".to_string(), |v| vm.display(v, ty))
            })
            .collect();
        trace.rows.push((k, ms, row));
        vm.advance(sc.cycle);
    }
    if fault.is_none() && done > 0 {
        // times after the last cycle refer to the last cycle
        let last = done - 1;
        let ms = i128::from(last) * sc.cycle / 1_000_000;
        for i in 0..expects.len() {
            if !results[i].checked {
                check_one(&vm, i, last, ms, &mut results);
            }
        }
    }
    let cmp = old.map(|o| compare(o, &trace));
    let programs = roots.iter().map(|(n, _, _)| n.clone()).collect();
    drop(vm);
    Ok(SimReport {
        check,
        programs,
        cycle: sc.cycle,
        cycles: done,
        fault,
        expectations: results,
        trace,
        compare: cmp,
    })
}

/// Text report.
pub fn render(r: &SimReport) -> String {
    let mut out = format!(
        "sim {}: {} cycle(s) of {} ms\n",
        r.programs.join(", "),
        r.cycles,
        r.cycle as f64 / 1e6
    );
    for e in &r.expectations {
        let x = &e.expect;
        match (&e.failed, e.checked) {
            (_, false) => out.push_str(&format!("  NOT CHECKED line {}: {}\n", x.line, x.text)),
            (None, true) => out.push_str(&format!("  ok   line {}: {}\n", x.line, x.text)),
            (Some((c, ms, v)), true) => out.push_str(&format!(
                "  FAIL line {}: {} (cycle {c}, {} s: {} = {v})\n",
                x.line,
                x.text,
                *ms as f64 / 1000.0,
                x.path
            )),
        }
    }
    if let Some((c, f)) = &r.fault {
        let (n, l, col) = crate::json::location(&r.check, f.file, f.span.start);
        out.push_str(&format!(
            "fault in cycle {c}: {n}:{l}:{col}: {}: {}\n",
            f.kind.name(),
            f.message
        ));
    }
    if let Some(last) = r.trace.rows.last() {
        for (p, v) in r.trace.paths.iter().zip(&last.2) {
            out.push_str(&format!("  {p} = {v}\n"));
        }
    }
    if let Some(c) = &r.compare {
        match &c.first {
            None if c.equal() => {
                out.push_str(&format!("trace: the same in all {} cycle(s)\n", c.cycles.1))
            }
            None => out.push_str(&format!(
                "trace: the same values, but {} cycle(s) in the trace and {} in the run\n",
                c.cycles.0, c.cycles.1
            )),
            Some(d) => out.push_str(&format!(
                "trace: first difference in cycle {} ({} s): {} was {}, now {}\n",
                d.cycle,
                d.time_ms as f64 / 1000.0,
                d.path,
                d.trace,
                d.run
            )),
        }
        if !c.only_trace.is_empty() {
            out.push_str(&format!(
                "  only in the trace: {}\n",
                c.only_trace.join(", ")
            ));
        }
        if !c.only_run.is_empty() {
            out.push_str(&format!("  only in the run: {}\n", c.only_run.join(", ")));
        }
    }
    out.push_str(if r.ok() { "ok\n" } else { "FAILED\n" });
    out
}

/// JSON report ([sim.run]).
pub fn to_json(r: &SimReport) -> String {
    let exps: Vec<String> = r
        .expectations
        .iter()
        .map(|e| {
            let fail = match &e.failed {
                Some((c, ms, v)) => format!(
                    ",\"cycle\":{c},\"time_ms\":{ms},\"value\":{}",
                    json_string(v)
                ),
                None => String::new(),
            };
            format!(
                "{{\"line\":{},\"text\":{},\"ok\":{},\"checked\":{}{fail}}}",
                e.expect.line,
                json_string(&e.expect.text),
                e.checked && e.ok,
                e.checked
            )
        })
        .collect();
    let fin: Vec<String> = match r.trace.rows.last() {
        Some(last) => r
            .trace
            .paths
            .iter()
            .zip(&last.2)
            .map(|(p, v)| format!("{}:{}", json_string(p), json_string(v)))
            .collect(),
        None => Vec::new(),
    };
    let cmp = match &r.compare {
        None => "null".to_string(),
        Some(c) => {
            let first = c.first.as_ref().map_or("null".to_string(), |d| {
                format!(
                    "{{\"cycle\":{},\"time_ms\":{},\"path\":{},\"trace\":{},\"run\":{}}}",
                    d.cycle,
                    d.time_ms,
                    json_string(&d.path),
                    json_string(&d.trace),
                    json_string(&d.run)
                )
            });
            let list = |v: &[String]| {
                format!(
                    "[{}]",
                    v.iter()
                        .map(|x| json_string(x))
                        .collect::<Vec<_>>()
                        .join(",")
                )
            };
            format!(
                "{{\"equal\":{},\"first\":{first},\"cycles_trace\":{},\"cycles_run\":{},\"only_trace\":{},\"only_run\":{}}}",
                c.equal(),
                c.cycles.0,
                c.cycles.1,
                list(&c.only_trace),
                list(&c.only_run)
            )
        }
    };
    let fault = match &r.fault {
        None => "null".to_string(),
        Some((c, f)) => {
            let inner = crate::json::fault(&r.check, Some(f));
            format!("{{\"cycle\":{c},\"at\":{inner}}}")
        }
    };
    format!(
        "{{\"command\":\"sim\",\"ok\":{},\"cycles\":{},\"fault\":{fault},\"diagnostics\":{},\"expectations\":[{}],\"final\":{{{}}},\"compare\":{cmp}}}",
        r.ok(),
        r.cycles,
        crate::json::diagnostics(&r.check),
        exps.join(","),
        fin.join(",")
    )
}
