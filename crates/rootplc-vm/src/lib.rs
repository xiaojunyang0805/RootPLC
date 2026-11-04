//! Deterministic execution of the typed IR. Runs `test`, `run` and (later)
//! `sim` and the Wasm playground.
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`. v0 interprets the IR directly; a
//! bytecode back end can replace the interpreter later without changing the
//! semantics, which follow spec/02-types.md exactly:
//! - integers wrap in two's complement at their declared width;
//! - `REAL` rounds to IEEE binary32 after every operation and store;
//! - integer division by zero, subrange violations, bad array indices and
//!   `NULL` dereferences raise faults; infinite loops hit the watchdog.

use rootplc_diag::Span;
use rootplc_sema::ir::{
    BinOp, Call, CallTarget, Const, DefKind, Expr, ExprKind, ForLoop, Init, Program, Section, Stmt,
    UnOp,
};
use rootplc_sema::{Elem, Ty};

/// A run-time value.
#[derive(Debug, Clone, PartialEq)]
pub enum Value {
    /// BOOL.
    Bool(bool),
    /// Integers, bit strings, enumerations, durations, dates, characters.
    Int(i128),
    /// REAL and LREAL.
    Real(f64),
    /// STRING and WSTRING.
    Str(String),
    /// Structure, array (row-major) or POU instance.
    Agg(Vec<Value>),
    /// Reference; `None` is NULL.
    Ref(Option<Loc>),
    /// Interface reference: an instance and its block; `None` is NULL,
    /// [pous.oop.interface-ref].
    Obj(Option<(Loc, usize)>),
}

/// An array type with a `*` dimension (`ARRAY[*] OF T`).
fn is_open(ty: &Ty) -> bool {
    matches!(ty, Ty::Array { dims, .. } if dims.iter().any(Option::is_none))
}

/// Bounds of an array type whose dimensions are all known.
fn fixed_dims(ty: &Ty) -> Option<Vec<(i128, i128)>> {
    match ty {
        Ty::Array { dims, .. } => dims.iter().copied().collect(),
        _ => None,
    }
}

/// [stdlib.functions.bounds]: a value stored in an open-array parameter
/// carries the bounds of the array passed in: element 0 is the header
/// `[lo1, hi1, ...]`, the elements follow.
fn open_header(v: &Value) -> Option<Vec<(i128, i128)>> {
    match v {
        Value::Agg(xs) => match xs.first()? {
            Value::Agg(h) => Some(h.chunks(2).map(|c| (int(&c[0]), int(&c[1]))).collect()),
            _ => None,
        },
        _ => None,
    }
}

/// A fixed array passed to an open-array parameter gets the bounds header.
fn open_wrap(param: &Ty, arg: &Ty, v: Value) -> Value {
    if !is_open(param) || is_open(arg) {
        return v;
    }
    match (fixed_dims(arg), v) {
        (Some(dims), Value::Agg(items)) => {
            let header = Value::Agg(
                dims.iter()
                    .flat_map(|&(lo, hi)| [Value::Int(lo), Value::Int(hi)])
                    .collect(),
            );
            let mut out = Vec::with_capacity(items.len() + 1);
            out.push(header);
            out.extend(items);
            Value::Agg(out)
        }
        (_, v) => v,
    }
}

/// Writing an open-array parameter back to a fixed array drops the header.
fn open_unwrap(param: &Ty, arg: &Ty, v: Value) -> Value {
    if !is_open(param) || is_open(arg) {
        return v;
    }
    match v {
        Value::Agg(mut items) if open_header(&Value::Agg(items.clone())).is_some() => {
            items.remove(0);
            Value::Agg(items)
        }
        v => v,
    }
}

/// The instance a THIS or THIS^ expression denotes.
fn is_this_expr(e: &Expr) -> bool {
    match &e.kind {
        ExprKind::This => true,
        ExprKind::Deref(r) => {
            matches!(&r.kind, ExprKind::Ref(x) if matches!(x.kind, ExprKind::This))
        }
        _ => false,
    }
}

/// Null-ness and target of a reference-like value, for comparisons.
fn obj_key(v: &Value) -> Option<Option<&Loc>> {
    match v {
        Value::Obj(x) => Some(x.as_ref().map(|(l, _)| l)),
        Value::Ref(None) | Value::Int(0) => Some(None),
        _ => None,
    }
}

/// A storage location: a root (program instance or call frame) and a path of
/// slot indices into nested aggregates.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Loc {
    /// Root index.
    pub root: usize,
    /// Slot path.
    pub path: Vec<u32>,
}

impl Loc {
    fn child(&self, i: usize) -> Loc {
        let mut l = self.clone();
        l.path.push(i as u32);
        l
    }
}

/// Run-time fault kinds (spec/06-tasks-config.md).
#[allow(missing_docs)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FaultKind {
    DivByZero,
    Range,
    Index,
    NullRef,
    Watchdog,
    Unsupported,
}

impl FaultKind {
    /// Name as reported to users.
    pub fn name(self) -> &'static str {
        match self {
            FaultKind::DivByZero => "DIV_BY_ZERO",
            FaultKind::Range => "RANGE",
            FaultKind::Index => "INDEX",
            FaultKind::NullRef => "NULL_REF",
            FaultKind::Watchdog => "WATCHDOG",
            FaultKind::Unsupported => "UNSUPPORTED",
        }
    }
}

/// A run-time fault with its location.
#[derive(Debug, Clone)]
pub struct Fault {
    /// Kind.
    pub kind: FaultKind,
    /// File index of the location.
    pub file: usize,
    /// Location.
    pub span: Span,
    /// Explanation.
    pub message: String,
}

/// A failed assertion (spec/07-test-blocks.md).
#[derive(Debug, Clone)]
pub struct AssertFailure {
    /// File index.
    pub file: usize,
    /// Location of the assertion.
    pub span: Span,
    /// What failed.
    pub message: String,
}

type R<T> = Result<T, Fault>;

enum Flow {
    Normal,
    Exit,
    Continue,
    Return,
}

struct Ctx {
    /// The current frame: a program, block or test instance, or a call frame.
    this: Loc,
    /// The instance a body or method runs on, and its type, [pous.oop.this].
    inst: Option<(Loc, usize)>,
}

/// Statements one cycle (or one test) may execute before the watchdog fires.
pub const STEP_BUDGET: u64 = 10_000_000;
const MAX_DEPTH: usize = 256;

/// The virtual machine.
pub struct Vm<'p> {
    prog: &'p Program,
    roots: Vec<Value>,
    /// The definition each root is an instance or frame of (parallel to
    /// `roots`): the type of any place follows from it, [pous.oop.override].
    root_defs: Vec<usize>,
    /// A fault raised by FB_init while instances were created; the next
    /// cycle reports it, [pous.oop.fb-init].
    startup_fault: Option<Fault>,
    /// Virtual clock in nanoseconds; timers read it.
    pub now_ns: i128,
    /// Failed assertions so far.
    pub failures: Vec<AssertFailure>,
    steps: u64,
    file: usize,
    /// Root holding the global variables, [config.global-list].
    globals: Option<usize>,
    /// [pous.call.in-out]: while a call runs, each VAR_IN_OUT slot and the
    /// caller's variable it was copied from; ADR / REF of the slot names
    /// the caller's variable.
    aliases: Vec<(Loc, Loc)>,
    /// [stdlib.compat.dynamic]: variables created by __NEW, at roots from
    /// [`HEAP`] on; `None` once freed by __DELETE.
    heap: Vec<Option<Value>>,
}

/// First root index of the heap ([`Vm::heap`]).
const HEAP: usize = 1 << 40;

fn truthy(v: &Value) -> bool {
    match v {
        Value::Bool(b) => *b,
        Value::Int(n) => *n != 0,
        Value::Real(x) => *x != 0.0,
        _ => false,
    }
}

fn int(v: &Value) -> i128 {
    match v {
        Value::Int(n) => *n,
        Value::Bool(b) => i128::from(*b),
        Value::Real(x) => *x as i128,
        _ => 0,
    }
}

fn real(v: &Value) -> f64 {
    match v {
        Value::Int(n) => *n as f64,
        Value::Real(x) => *x,
        Value::Bool(b) => f64::from(u8::from(*b)),
        _ => 0.0,
    }
}

/// Two's-complement wrap to the width of `e` (no-op for types without range).
pub fn wrap(n: i128, e: Elem) -> i128 {
    match e.int_range() {
        Some((lo, hi)) => (n - lo).rem_euclid(hi - lo + 1) + lo,
        None => n,
    }
}

/// [types.conversion.explicit]: real to integer rounds half away from zero,
/// saturates, and maps NaN to 0.
fn real_to_int(x: f64, e: Elem) -> i128 {
    if x.is_nan() {
        return 0;
    }
    let r = x.round();
    match e.int_range() {
        Some((lo, hi)) => {
            if r <= lo as f64 {
                lo
            } else if r >= hi as f64 {
                hi
            } else {
                r as i128
            }
        }
        None => r as i128,
    }
}

fn bit_width(e: Elem) -> u32 {
    match e {
        Elem::Bool => 1,
        Elem::Byte | Elem::Sint | Elem::Usint => 8,
        Elem::Word | Elem::Int | Elem::Uint => 16,
        Elem::Dword | Elem::Dint | Elem::Udint => 32,
        _ => 64,
    }
}

fn conv_elem(v: Value, e: Elem) -> Value {
    match e {
        Elem::Bool => Value::Bool(truthy(&v)),
        Elem::Real => Value::Real(real(&v) as f32 as f64),
        Elem::Lreal => Value::Real(real(&v)),
        _ => {
            let n = match v {
                Value::Real(x) => real_to_int(x, e),
                Value::Str(s) => {
                    if matches!(e, Elem::Char | Elem::Wchar) {
                        s.chars().next().map_or(0, |c| i128::from(c as u32))
                    } else {
                        s.trim().parse().unwrap_or(0)
                    }
                }
                other => int(&other),
            };
            Value::Int(wrap(n, e))
        }
    }
}

/// `yyyy-mm-dd` of a day count since 1970-01-01 (proleptic Gregorian).
fn civil_date(days: i128) -> String {
    // Howard Hinnant's days_from_civil inverse
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + i128::from(m <= 2);
    format!("{y:04}-{m:02}-{d:02}")
}

/// `hh:mm:ss[.f]` of a time of day given in units of 1/`per_s` second.
fn clock(t: i128, per_s: i128) -> String {
    let t = t.rem_euclid(86_400 * per_s);
    let (secs, frac) = (t / per_s, t % per_s);
    let mut s = format!("{:02}:{:02}:{:02}", secs / 3600, secs / 60 % 60, secs % 60);
    if frac != 0 {
        let width = per_s.to_string().len() - 1;
        let f = format!("{frac:0width$}");
        s.push('.');
        s.push_str(f.trim_end_matches('0'));
    }
    s
}

fn to_text(v: &Value) -> String {
    match v {
        Value::Bool(b) => if *b { "TRUE" } else { "FALSE" }.to_string(),
        Value::Int(n) => n.to_string(),
        Value::Real(x) => x.to_string(),
        Value::Str(s) => s.clone(),
        _ => String::new(),
    }
}

fn compare(a: &Value, b: &Value) -> Option<std::cmp::Ordering> {
    if matches!(a, Value::Obj(_)) || matches!(b, Value::Obj(_)) {
        let (x, y) = (obj_key(a), obj_key(b));
        return Some(if x.is_some() && x == y {
            std::cmp::Ordering::Equal
        } else {
            std::cmp::Ordering::Less
        });
    }
    match (a, b) {
        // 0 compared with a reference is NULL (CODESYS / TwinCAT, RP0127)
        (Value::Ref(_), Value::Int(0)) => compare(a, &Value::Ref(None)),
        (Value::Int(0), Value::Ref(_)) => compare(&Value::Ref(None), b),
        (Value::Str(x), Value::Str(y)) => Some(x.cmp(y)),
        (Value::Bool(x), Value::Bool(y)) => Some(x.cmp(y)),
        (Value::Real(_), _) | (_, Value::Real(_)) => real(a).partial_cmp(&real(b)),
        (Value::Ref(x), Value::Ref(y)) => Some(if x == y {
            std::cmp::Ordering::Equal
        } else {
            std::cmp::Ordering::Less
        }),
        (Value::Agg(x), Value::Agg(y)) => Some(if x == y {
            std::cmp::Ordering::Equal
        } else {
            std::cmp::Ordering::Less
        }),
        _ => Some(int(a).cmp(&int(b))),
    }
}

impl<'p> Vm<'p> {
    /// A machine for one program.
    pub fn new(prog: &'p Program) -> Self {
        let mut vm = Vm {
            prog,
            roots: Vec::new(),
            root_defs: Vec::new(),
            startup_fault: None,
            now_ns: 0,
            failures: Vec::new(),
            steps: 0,
            file: 0,
            globals: None,
            aliases: Vec::new(),
            heap: Vec::new(),
        };
        if let Some(g) = prog.globals {
            vm.globals = Some(vm.instantiate(g));
        }
        vm
    }

    fn fault(&self, kind: FaultKind, span: Span, message: impl Into<String>) -> Fault {
        Fault {
            kind,
            file: self.file,
            span,
            message: message.into(),
        }
    }

    // ---------------------------------------------------------------- types

    fn strip(&self, t: &Ty) -> Ty {
        match t {
            Ty::Named(i) => match &self.prog.defs[*i].kind {
                DefKind::Subrange { base, .. } => Ty::Elem(*base),
                DefKind::Alias(t) => self.strip(t),
                _ => t.clone(),
            },
            _ => t.clone(),
        }
    }

    fn elem(&self, t: &Ty) -> Option<Elem> {
        match self.strip(t) {
            Ty::Elem(e) => Some(e),
            Ty::IntLit => Some(Elem::Lint),
            Ty::RealLit => Some(Elem::Lreal),
            _ => None,
        }
    }

    /// Convert a value for storage in `ty`, [types.conversion.implicit].
    fn convert(&self, v: Value, ty: &Ty) -> Result<Value, FaultKind> {
        match ty {
            Ty::Elem(e) => Ok(conv_elem(v, *e)),
            // 0 stored in a reference is NULL (CODESYS / TwinCAT, RP0127)
            Ty::Ref(_) if matches!(v, Value::Int(0)) => Ok(Value::Ref(None)),
            Ty::Str { len, .. } => Ok(match v {
                Value::Str(s) => Value::Str(s.chars().take(*len as usize).collect()),
                Value::Int(c) => Value::Str(
                    char::from_u32(c as u32)
                        .map(String::from)
                        .unwrap_or_default(),
                ),
                other => Value::Str(to_text(&other)),
            }),
            Ty::Named(i) => match &self.prog.defs[*i].kind {
                DefKind::Subrange { base, lo, hi } => {
                    let v = conv_elem(v, *base);
                    match v {
                        Value::Int(n) if n < *lo || n > *hi => Err(FaultKind::Range),
                        v => Ok(v),
                    }
                }
                DefKind::Alias(t) => self.convert(v, t),
                // 0 or NULL stored in an interface clears it
                DefKind::Pou(p)
                    if p.kind == rootplc_sema::ir::PouKind::Interface
                        && matches!(v, Value::Int(0) | Value::Ref(None)) =>
                {
                    Ok(Value::Obj(None))
                }
                _ => Ok(v),
            },
            _ => Ok(v),
        }
    }

    /// Default value of a type, [types.default-init].
    pub fn default_value(&self, ty: &Ty) -> Value {
        match ty {
            Ty::Elem(Elem::Bool) => Value::Bool(false),
            Ty::Elem(Elem::Real | Elem::Lreal) | Ty::RealLit => Value::Real(0.0),
            Ty::Elem(_) | Ty::IntLit | Ty::Unknown => Value::Int(0),
            Ty::Str { .. } => Value::Str(String::new()),
            Ty::Array { dims, elem } => {
                let n: usize = dims
                    .iter()
                    .map(|d| d.map_or(0, |(a, b)| (b - a + 1) as usize))
                    .product();
                Value::Agg(vec![self.default_value(elem); n])
            }
            Ty::Ref(_) | Ty::Null => Value::Ref(None),
            Ty::Named(i) => self.default_named(*i),
        }
    }

    fn default_named(&self, i: usize) -> Value {
        let d = &self.prog.defs[i];
        match &d.kind {
            DefKind::Struct(fields) => Value::Agg(
                fields
                    .iter()
                    .map(|f| self.init_value(&f.ty, f.init.as_ref()))
                    .collect(),
            ),
            DefKind::Enum(v) => Value::Int(v.first().map_or(0, |x| x.1)),
            DefKind::Subrange { lo, .. } => Value::Int(*lo),
            DefKind::Alias(t) => self.default_value(t),
            DefKind::Pou(p) if p.kind == rootplc_sema::ir::PouKind::Interface => Value::Obj(None),
            DefKind::Pou(p) => {
                let mut v: Vec<Value> = p
                    .vars
                    .iter()
                    .map(|f| self.init_value(&f.ty, f.init.as_ref()))
                    .collect();
                if p.builtin {
                    v.extend(std::iter::repeat_n(Value::Int(0), 3));
                }
                Value::Agg(v)
            }
            DefKind::Unresolved => Value::Int(0),
        }
    }

    fn init_value(&self, ty: &Ty, init: Option<&Init>) -> Value {
        match init {
            None => self.default_value(ty),
            Some(Init::Expr(e)) => self
                .const_eval(e)
                .and_then(|v| self.convert(v, ty).ok())
                .unwrap_or_else(|| self.default_value(ty)),
            Some(Init::Array(items)) => {
                let mut d = self.default_value(ty);
                if let (Value::Agg(slots), Ty::Array { elem, .. }) = (&mut d, &self.strip(ty)) {
                    for (k, it) in items.iter().enumerate().take(slots.len()) {
                        slots[k] = self.init_value(elem, Some(it));
                    }
                }
                d
            }
            Some(Init::Struct(fields)) => {
                let mut d = self.default_value(ty);
                if let (Value::Agg(slots), Ty::Named(i)) = (&mut d, ty) {
                    // structure members, or a function-block instance's variables
                    let tys: Vec<Ty> = match &self.prog.defs[*i].kind {
                        DefKind::Struct(fs) => fs.iter().map(|f| f.ty.clone()).collect(),
                        DefKind::Pou(p) => p.vars.iter().map(|v| v.ty.clone()).collect(),
                        _ => Vec::new(),
                    };
                    for (k, it) in fields {
                        if let (Some(t), true) = (tys.get(*k), *k < slots.len()) {
                            slots[*k] = self.init_value(t, Some(it));
                        }
                    }
                }
                d
            }
        }
    }

    /// Value of a constant expression (initial values).
    fn const_eval(&self, e: &Expr) -> Option<Value> {
        match &e.kind {
            ExprKind::Const(c) => Some(const_value(c)),
            ExprKind::Null => Some(Value::Ref(None)),
            ExprKind::Unary(UnOp::Neg, x) => match self.const_eval(x)? {
                Value::Int(n) => Some(Value::Int(-n)),
                Value::Real(r) => Some(Value::Real(-r)),
                _ => None,
            },
            ExprKind::Binary { op, opty, l, r } => {
                let (a, b) = (self.const_eval(l)?, self.const_eval(r)?);
                self.binop(*op, opty, &e.ty, a, b).ok()
            }
            _ => None,
        }
    }

    // ---------------------------------------------------------------- storage

    fn get(&self, loc: &Loc, span: Span) -> R<&Value> {
        let root = if loc.root >= HEAP {
            self.heap.get(loc.root - HEAP).and_then(Option::as_ref)
        } else {
            self.roots.get(loc.root)
        };
        let mut v =
            root.ok_or_else(|| self.fault(FaultKind::NullRef, span, "dangling reference"))?;
        for &i in &loc.path {
            v = match v {
                Value::Agg(xs) => xs.get(i as usize),
                _ => None,
            }
            .ok_or_else(|| self.fault(FaultKind::Unsupported, span, "invalid location"))?;
        }
        Ok(v)
    }

    fn get_mut(&mut self, loc: &Loc, span: Span) -> R<&mut Value> {
        let bad = self.fault(FaultKind::Unsupported, span, "invalid location");
        let mut v = if loc.root >= HEAP {
            let dangling = self.fault(FaultKind::NullRef, span, "dangling reference (__DELETE)");
            self.heap
                .get_mut(loc.root - HEAP)
                .and_then(Option::as_mut)
                .ok_or(dangling)?
        } else {
            self.roots.get_mut(loc.root).ok_or_else(|| bad.clone())?
        };
        for &i in &loc.path {
            v = match v {
                Value::Agg(xs) => xs.get_mut(i as usize),
                _ => None,
            }
            .ok_or_else(|| bad.clone())?;
        }
        Ok(v)
    }

    fn store(&mut self, loc: &Loc, v: Value, ty: &Ty, span: Span) -> R<()> {
        let v = self
            .convert(v, ty)
            .map_err(|k| self.fault(k, span, "value outside the subrange"))?;
        *self.get_mut(loc, span)? = v;
        Ok(())
    }

    // ---------------------------------------------------------------- public API

    /// Create an instance of a program, function block or test. Returns its root.
    pub fn instantiate(&mut self, def: usize) -> usize {
        let v = self.default_named(def);
        self.roots.push(v);
        self.root_defs.push(def);
        let root = self.roots.len() - 1;
        // [pous.oop.fb-init]: FB_init of every block instance, inner ones first
        if let Err(f) = self.fb_init_tree(
            &Loc {
                root,
                path: Vec::new(),
            },
            &Ty::Named(def),
        ) {
            self.startup_fault.get_or_insert(f);
        }
        root
    }

    /// Run FB_init (bInitRetains TRUE, bInCopyCode FALSE) on each function
    /// block instance inside the place `at` of type `ty`, inner instances
    /// before the one containing them, in declaration order.
    fn fb_init_tree(&mut self, at: &Loc, ty: &Ty) -> R<()> {
        let prog = self.prog;
        match self.strip(ty) {
            Ty::Array { elem, dims } => {
                let n: usize = dims
                    .iter()
                    .map(|d| d.map_or(0, |(a, b)| (b - a + 1) as usize))
                    .product();
                for k in 0..n {
                    self.fb_init_tree(&at.child(k), &elem)?;
                }
            }
            Ty::Named(d) => match &prog.defs[d].kind {
                DefKind::Struct(fields) => {
                    for (k, f) in fields.iter().enumerate() {
                        self.fb_init_tree(&at.child(k), &f.ty)?;
                    }
                }
                DefKind::Pou(p) if !p.builtin && p.kind != rootplc_sema::ir::PouKind::Interface => {
                    for (k, v) in p.vars.iter().enumerate() {
                        if v.section != Section::InOut && !matches!(v.ty, Ty::Ref(_)) {
                            self.fb_init_tree(&at.child(k), &v.ty)?;
                        }
                    }
                    if let Some(&(_, m)) = p
                        .methods
                        .iter()
                        .find(|(n, _)| n.eq_ignore_ascii_case("FB_init"))
                    {
                        let args = prog.pou(m).map_or(Vec::new(), |mp| {
                            mp.vars
                                .iter()
                                .enumerate()
                                .filter(|(_, v)| v.section == Section::Input)
                                .filter_map(|(k, v)| {
                                    if v.name.eq_ignore_ascii_case("bInitRetains") {
                                        Some((k, Value::Bool(true)))
                                    } else if v.name.eq_ignore_ascii_case("bInCopyCode") {
                                        Some((k, Value::Bool(false)))
                                    } else {
                                        None
                                    }
                                })
                                .collect()
                        });
                        self.call_method_direct(m, at.clone(), d, &args)?;
                    }
                }
                _ => {}
            },
            _ => {}
        }
        Ok(())
    }

    /// Call method `m` on the instance at `inst` (of block `rt`) with the
    /// given input values, outside any expression (FB_init at start-up).
    fn call_method_direct(
        &mut self,
        m: usize,
        inst: Loc,
        rt: usize,
        args: &[(usize, Value)],
    ) -> R<()> {
        let prog = self.prog;
        let Some(pou) = prog.pou(m) else {
            return Ok(());
        };
        let frame = self.default_named(m);
        self.roots.push(frame);
        self.root_defs.push(m);
        let root = self.roots.len() - 1;
        let floc = Loc {
            root,
            path: Vec::new(),
        };
        for (slot, v) in args {
            self.store(
                &floc.child(*slot),
                v.clone(),
                &pou.vars[*slot].ty,
                Span::new(0, 0),
            )?;
        }
        let saved = self.file;
        self.file = prog.defs[m].file;
        self.steps = 0;
        let r = self.exec_block(
            &pou.body,
            &Ctx {
                this: floc,
                inst: Some((inst, rt)),
            },
        );
        self.file = saved;
        self.roots.truncate(root);
        self.root_defs.truncate(root);
        r.map(|_| ())
    }

    /// The function block or program stored at `loc`, from the type of its
    /// root and the slot path: through a reference or pointer this is the
    /// instance's own block, a derived one included, [pous.oop.override].
    fn block_at(&self, loc: &Loc) -> Option<usize> {
        let prog = self.prog;
        let mut ty = Ty::Named(*self.root_defs.get(loc.root)?);
        for &k in &loc.path {
            ty = match self.strip(&ty) {
                Ty::Array { elem, .. } => *elem,
                Ty::Named(d) => match &prog.defs[d].kind {
                    DefKind::Struct(fields) => fields.get(k as usize)?.ty.clone(),
                    DefKind::Pou(p) => p.vars.get(k as usize)?.ty.clone(),
                    _ => return None,
                },
                _ => return None,
            };
        }
        match self.strip(&ty) {
            Ty::Named(d) if prog.pou(d).is_some() => Some(d),
            _ => None,
        }
    }

    /// Whether block `d` is `base` or extends it, [pous.oop.extends].
    fn extends(&self, mut d: usize, base: usize) -> bool {
        for _ in 0..64 {
            if d == base {
                return true;
            }
            match self.prog.pou(d).and_then(|p| p.base) {
                Some(b) => d = b,
                None => return false,
            }
        }
        false
    }

    /// Execute the body of POU `def` once on the instance at `root` (one cycle).
    pub fn cycle(&mut self, root: usize, def: usize) -> R<()> {
        if let Some(f) = self.startup_fault.take() {
            return Err(f);
        }
        self.steps = 0;
        let Some(pou) = self.prog.pou(def) else {
            return Ok(());
        };
        self.file = self.prog.defs[def].file;
        let here = Loc {
            root,
            path: Vec::new(),
        };
        let cx = Ctx {
            this: here.clone(),
            inst: Some((here, def)),
        };
        self.exec_block(&pou.body, &cx).map(|_| ())
    }

    /// Advance the virtual clock.
    pub fn advance(&mut self, ns: i128) {
        self.now_ns += ns;
    }

    /// Current value of a variable of the instance at `root`.
    pub fn read_var(&self, root: usize, def: usize, name: &str) -> Option<&Value> {
        let pou = self.prog.pou(def)?;
        let i = pou
            .vars
            .iter()
            .position(|v| v.name.eq_ignore_ascii_case(name))?;
        match self.roots.get(root)? {
            Value::Agg(xs) => xs.get(i),
            _ => None,
        }
    }

    /// Set a variable of the instance at `root` (for example an input from a
    /// simulator or a test harness). The value is converted to the variable's
    /// type; returns false if the variable does not exist or the value does
    /// not fit (subrange).
    pub fn write_var(&mut self, root: usize, def: usize, name: &str, v: Value) -> bool {
        let Some(pou) = self.prog.pou(def) else {
            return false;
        };
        let Some(i) = pou
            .vars
            .iter()
            .position(|x| x.name.eq_ignore_ascii_case(name))
        else {
            return false;
        };
        let Ok(v) = self.convert(v, &pou.vars[i].ty) else {
            return false;
        };
        match self.roots.get_mut(root) {
            Some(Value::Agg(xs)) if i < xs.len() => {
                xs[i] = v;
                true
            }
            _ => false,
        }
    }

    /// Render a value of type `ty` as IEC literal text.
    pub fn display(&self, v: &Value, ty: &Ty) -> String {
        match (v, self.strip(ty)) {
            (Value::Int(n), Ty::Elem(Elem::Time)) => format!("T#{n}ms"),
            (Value::Int(n), Ty::Elem(Elem::Ltime)) => format!("LT#{n}ns"),
            // [types.elementary]: DATE / DT in seconds, TOD in ms, L types in ns
            (Value::Int(n), Ty::Elem(Elem::Date)) => {
                format!("D#{}", civil_date(n.div_euclid(86_400)))
            }
            (Value::Int(n), Ty::Elem(Elem::Ldate)) => {
                format!("LD#{}", civil_date(n.div_euclid(86_400 * 1_000_000_000)))
            }
            (Value::Int(n), Ty::Elem(Elem::Tod)) => format!("TOD#{}", clock(*n, 1_000)),
            (Value::Int(n), Ty::Elem(Elem::Ltod)) => format!("LTOD#{}", clock(*n, 1_000_000_000)),
            (Value::Int(n), Ty::Elem(Elem::Dt)) => format!(
                "DT#{}-{}",
                civil_date(n.div_euclid(86_400)),
                clock(n.rem_euclid(86_400), 1)
            ),
            (Value::Int(n), Ty::Elem(Elem::Ldt)) => {
                let day = 86_400 * 1_000_000_000;
                format!(
                    "LDT#{}-{}",
                    civil_date(n.div_euclid(day)),
                    clock(n.rem_euclid(day), 1_000_000_000)
                )
            }
            (Value::Int(n), Ty::Named(i)) => match &self.prog.defs[i].kind {
                DefKind::Enum(vals) => match vals.iter().find(|(_, x)| x == n) {
                    Some((name, _)) => format!("{}#{name}", self.prog.defs[i].name),
                    None => n.to_string(),
                },
                _ => n.to_string(),
            },
            (Value::Real(x), _) => format!("{x:?}"),
            (Value::Str(s), Ty::Str { wide: true, .. }) => format!("\"{s}\""),
            (Value::Str(s), _) => format!("'{s}'"),
            (Value::Ref(None) | Value::Obj(None), _) => "NULL".into(),
            (Value::Obj(Some(_)), _) => "REF(...)".into(),
            (Value::Ref(Some(_)), _) => "REF(...)".into(),
            (Value::Agg(xs), Ty::Array { elem, .. }) => {
                let parts: Vec<String> = xs.iter().map(|x| self.display(x, &elem)).collect();
                format!("[{}]", parts.join(", "))
            }
            (Value::Agg(xs), Ty::Named(i)) => {
                let fields: Vec<(String, Ty)> = match &self.prog.defs[i].kind {
                    DefKind::Struct(f) => {
                        f.iter().map(|f| (f.name.clone(), f.ty.clone())).collect()
                    }
                    DefKind::Pou(p) => p
                        .vars
                        .iter()
                        .map(|f| (f.name.clone(), f.ty.clone()))
                        .collect(),
                    _ => Vec::new(),
                };
                let parts: Vec<String> = fields
                    .iter()
                    .zip(xs)
                    .map(|((n, t), x)| format!("{n} := {}", self.display(x, t)))
                    .collect();
                format!("({})", parts.join(", "))
            }
            (v, _) => to_text(v),
        }
    }

    // ---------------------------------------------------------------- statements

    fn tick(&mut self, span: Span) -> R<()> {
        self.steps += 1;
        if self.steps > STEP_BUDGET {
            return Err(self.fault(
                FaultKind::Watchdog,
                span,
                format!("more than {STEP_BUDGET} statements in one cycle (endless loop?)"),
            ));
        }
        Ok(())
    }

    fn exec_block(&mut self, b: &[Stmt], cx: &Ctx) -> R<Flow> {
        for s in b {
            match self.exec(s, cx)? {
                Flow::Normal => {}
                f => return Ok(f),
            }
        }
        Ok(Flow::Normal)
    }

    fn exec(&mut self, s: &Stmt, cx: &Ctx) -> R<Flow> {
        self.tick(Span::new(0, 0))?;
        match s {
            Stmt::Assign(t, v) => {
                let val = self.eval(v, cx)?;
                let loc = self.place(t, cx)?;
                self.store(&loc, val, &t.ty, t.span)?;
            }
            Stmt::Eval(e) => {
                self.eval(e, cx)?;
            }
            Stmt::If(arms, els) => {
                for (c, b) in arms {
                    if truthy(&self.eval(c, cx)?) {
                        return self.exec_block(b, cx);
                    }
                }
                return self.exec_block(els, cx);
            }
            Stmt::Case { sel, arms, default } => {
                let v = int(&self.eval(sel, cx)?);
                for arm in arms {
                    if arm.labels.iter().any(|(lo, hi)| v >= *lo && v <= *hi) {
                        return self.exec_block(&arm.body, cx);
                    }
                }
                return self.exec_block(default, cx);
            }
            Stmt::For(f) => {
                let ForLoop {
                    var,
                    from,
                    to,
                    by,
                    body,
                } = &**f;
                let loc = self.place(var, cx)?;
                let start = self.eval(from, cx)?;
                let end = int(&self.eval(to, cx)?);
                let step = match by {
                    Some(b) => int(&self.eval(b, cx)?),
                    None => 1,
                };
                self.store(&loc, start, &var.ty, var.span)?;
                loop {
                    let i = int(self.get(&loc, var.span)?);
                    if (step >= 0 && i > end) || (step < 0 && i < end) {
                        break;
                    }
                    match self.exec_block(body, cx)? {
                        Flow::Exit => break,
                        Flow::Return => return Ok(Flow::Return),
                        _ => {}
                    }
                    self.tick(var.span)?;
                    let i = int(self.get(&loc, var.span)?);
                    self.store(&loc, Value::Int(i + step), &var.ty, var.span)?;
                }
            }
            Stmt::While(c, b) => loop {
                if !truthy(&self.eval(c, cx)?) {
                    break;
                }
                match self.exec_block(b, cx)? {
                    Flow::Exit => break,
                    Flow::Return => return Ok(Flow::Return),
                    _ => self.tick(c.span)?,
                }
            },
            Stmt::Repeat(b, c) => loop {
                match self.exec_block(b, cx)? {
                    Flow::Exit => break,
                    Flow::Return => return Ok(Flow::Return),
                    _ => self.tick(c.span)?,
                }
                if truthy(&self.eval(c, cx)?) {
                    break;
                }
            },
            Stmt::Exit => return Ok(Flow::Exit),
            Stmt::Continue => return Ok(Flow::Continue),
            Stmt::Return => return Ok(Flow::Return),
        }
        Ok(Flow::Normal)
    }

    // ---------------------------------------------------------------- expressions

    fn place(&mut self, e: &Expr, cx: &Ctx) -> R<Loc> {
        match &e.kind {
            ExprKind::Var(i) => Ok(cx.this.child(*i)),
            ExprKind::This => match &cx.inst {
                Some((l, _)) => Ok(l.clone()),
                None => Err(self.fault(FaultKind::Unsupported, e.span, "THIS outside an instance")),
            },
            ExprKind::Global(i) => Ok(Loc {
                root: self.globals.unwrap_or(0),
                path: vec![*i as u32],
            }),
            ExprKind::Member(b, i) => {
                // [types.derived.union]: members share storage, which the VM
                // does not model yet
                if let Ty::Named(id) = self.strip(&b.ty) {
                    if self.prog.unions.binary_search(&id).is_ok() {
                        return Err(self.fault(
                            FaultKind::Unsupported,
                            e.span,
                            "UNION members share storage; the VM does not run unions yet",
                        ));
                    }
                }
                Ok(self.place(b, cx)?.child(*i))
            }
            ExprKind::Index(b, idx) => {
                let static_ty = self.strip(&b.ty);
                if !matches!(static_ty, Ty::Array { .. }) {
                    return Err(self.fault(FaultKind::Unsupported, e.span, "indexing a non-array"));
                }
                let base = self.place(b, cx)?;
                // an open array carries the bounds of the array passed in
                let (dims, skip): (Vec<Option<(i128, i128)>>, i128) = if is_open(&static_ty) {
                    let v = self.get(&base, e.span)?;
                    match open_header(v) {
                        Some(h) => (h.into_iter().map(Some).collect(), 1),
                        None => {
                            return Err(self.fault(
                                FaultKind::Unsupported,
                                e.span,
                                "open array without bounds",
                            ));
                        }
                    }
                } else if let Ty::Array { dims, .. } = static_ty {
                    (dims, 0)
                } else {
                    (Vec::new(), 0)
                };
                let mut off: i128 = 0;
                for (k, ie) in idx.iter().enumerate() {
                    let v = int(&self.eval(ie, cx)?);
                    let Some(Some((lo, hi))) = dims.get(k).copied() else {
                        return Err(self.fault(
                            FaultKind::Unsupported,
                            ie.span,
                            "array with open bounds",
                        ));
                    };
                    if v < lo || v > hi {
                        return Err(self.fault(
                            FaultKind::Index,
                            ie.span,
                            format!("index {v} is outside {lo}..{hi}"),
                        ));
                    }
                    off = off * (hi - lo + 1) + (v - lo);
                }
                Ok(base.child((off + skip) as usize))
            }
            ExprKind::Deref(b) => match self.eval(b, cx)? {
                Value::Ref(Some(l)) => Ok(l),
                _ => Err(self.fault(FaultKind::NullRef, e.span, "dereferencing NULL")),
            },
            _ => Err(self.fault(FaultKind::Unsupported, e.span, "not a variable")),
        }
    }

    fn eval(&mut self, e: &Expr, cx: &Ctx) -> R<Value> {
        match &e.kind {
            ExprKind::Const(c) => Ok(const_value(c)),
            ExprKind::Null => Ok(Value::Ref(None)),
            ExprKind::Var(_)
            | ExprKind::Global(_)
            | ExprKind::This
            | ExprKind::Member(..)
            | ExprKind::Index(..)
            | ExprKind::Deref(_) => {
                let loc = self.place(e, cx)?;
                Ok(self.get(&loc, e.span)?.clone())
            }
            ExprKind::Bit(b, n) => {
                let v = int(&self.eval(b, cx)?);
                Ok(Value::Bool((v >> n) & 1 == 1))
            }
            ExprKind::Ref(x) => {
                let l = self.place(x, cx)?;
                Ok(Value::Ref(Some(self.unalias(l))))
            }
            ExprKind::Unary(op, x) => {
                let v = self.eval(x, cx)?;
                let el = self.elem(&e.ty);
                Ok(match (op, v) {
                    (UnOp::Neg, Value::Int(n)) => Value::Int(el.map_or(-n, |el| wrap(-n, el))),
                    (UnOp::Neg, Value::Real(r)) => Value::Real(-r),
                    (UnOp::Not, Value::Bool(b)) => Value::Bool(!b),
                    (UnOp::Not, Value::Int(n)) => Value::Int(el.map_or(!n, |el| wrap(!n, el))),
                    (_, v) => v,
                })
            }
            ExprKind::Binary { op, opty, l, r } => {
                if matches!(op, BinOp::AndThen | BinOp::OrElse) {
                    let a = truthy(&self.eval(l, cx)?);
                    if (*op == BinOp::AndThen) != a {
                        return Ok(Value::Bool(a));
                    }
                    return Ok(Value::Bool(truthy(&self.eval(r, cx)?)));
                }
                let a = self.eval(l, cx)?;
                let b = self.eval(r, cx)?;
                self.binop(*op, opty, &e.ty, a, b)
                    .map_err(|k| self.fault(k, e.span, "division by zero"))
            }
            ExprKind::Call(c) => self.call(c, e, cx),
            ExprKind::ToItf(x, fb) => {
                let rt = match &cx.inst {
                    Some((_, d)) if is_this_expr(x) => *d,
                    _ => *fb,
                };
                let loc = self.place(x, cx)?;
                Ok(Value::Obj(Some((loc, rt))))
            }
            ExprKind::Invalid => Err(self.fault(
                FaultKind::Unsupported,
                e.span,
                "expression not supported by the VM yet",
            )),
        }
    }

    /// Binary operator on values; operands are treated as `opty`.
    fn binop(
        &self,
        op: BinOp,
        opty: &Ty,
        rty: &Ty,
        a: Value,
        b: Value,
    ) -> Result<Value, FaultKind> {
        use std::cmp::Ordering::*;
        if matches!(
            op,
            BinOp::Eq | BinOp::Ne | BinOp::Lt | BinOp::Gt | BinOp::Le | BinOp::Ge
        ) {
            let o = compare(&a, &b);
            return Ok(Value::Bool(match op {
                BinOp::Eq => o == Some(Equal),
                BinOp::Ne => o != Some(Equal),
                BinOp::Lt => o == Some(Less),
                BinOp::Gt => o == Some(Greater),
                BinOp::Le => matches!(o, Some(Less | Equal)),
                _ => matches!(o, Some(Greater | Equal)),
            }));
        }
        let el = self.elem(opty);
        let rel = self.elem(rty).or(el);
        if matches!(op, BinOp::And | BinOp::Or | BinOp::Xor) {
            return Ok(match (a, b) {
                (Value::Bool(x), Value::Bool(y)) => Value::Bool(match op {
                    BinOp::And => x && y,
                    BinOp::Or => x || y,
                    _ => x ^ y,
                }),
                (x, y) => {
                    let (x, y) = (int(&x), int(&y));
                    let n = match op {
                        BinOp::And => x & y,
                        BinOp::Or => x | y,
                        _ => x ^ y,
                    };
                    Value::Int(rel.map_or(n, |e| wrap(n, e)))
                }
            });
        }
        let is_real = matches!(el, Some(Elem::Real | Elem::Lreal))
            || matches!(a, Value::Real(_))
            || matches!(b, Value::Real(_));
        if is_real {
            let (x, y) = (real(&a), real(&b));
            let r = match op {
                BinOp::Add => x + y,
                BinOp::Sub => x - y,
                BinOp::Mul => x * y,
                BinOp::Div => x / y,
                BinOp::Mod => x % y,
                _ => x.powf(y),
            };
            return Ok(Value::Real(if rel == Some(Elem::Real) {
                r as f32 as f64
            } else {
                r
            }));
        }
        let (x, y) = (int(&a), int(&b));
        let n = match op {
            BinOp::Add => x.wrapping_add(y),
            BinOp::Sub => x.wrapping_sub(y),
            BinOp::Mul => x.wrapping_mul(y),
            BinOp::Div => {
                if y == 0 {
                    return Err(FaultKind::DivByZero);
                }
                x.wrapping_div(y)
            }
            BinOp::Mod => {
                if y == 0 {
                    return Err(FaultKind::DivByZero);
                }
                x.wrapping_rem(y)
            }
            _ => {
                if y < 0 {
                    0
                } else {
                    x.wrapping_pow(u32::try_from(y).unwrap_or(u32::MAX))
                }
            }
        };
        Ok(Value::Int(rel.map_or(n, |e| wrap(n, e))))
    }

    // ---------------------------------------------------------------- calls

    /// The caller's variables behind the VAR_IN_OUT slots of a call, to
    /// register while it runs ([`Vm::aliases`]). Open-array parameters carry
    /// a bounds header and are not aliased.
    fn in_out_aliases(
        &mut self,
        c: &Call,
        pou: &rootplc_sema::ir::Pou,
        frame: &Loc,
        cx: &Ctx,
    ) -> R<Vec<(Loc, Loc)>> {
        let mut out = Vec::new();
        for (slot, ex) in &c.inputs {
            if pou.vars[*slot].section != Section::InOut
                || is_open(&pou.vars[*slot].ty)
                || !matches!(
                    ex.kind,
                    ExprKind::Var(_)
                        | ExprKind::Global(_)
                        | ExprKind::Member(..)
                        | ExprKind::Index(..)
                        | ExprKind::Deref(_)
                )
            {
                continue;
            }
            let target = self.place(ex, cx)?;
            out.push((frame.child(*slot), self.unalias(target)));
        }
        Ok(out)
    }

    /// `l`, or the caller's variable when `l` lies in a VAR_IN_OUT slot of a
    /// running call.
    fn unalias(&self, mut l: Loc) -> Loc {
        loop {
            let hit = self
                .aliases
                .iter()
                .rev()
                .find(|(slot, _)| slot.root == l.root && l.path.starts_with(&slot.path));
            match hit {
                Some((slot, target)) => {
                    let mut path = target.path.clone();
                    path.extend_from_slice(&l.path[slot.path.len()..]);
                    l = Loc {
                        root: target.root,
                        path,
                    };
                }
                None => return l,
            }
        }
    }

    /// [pous.call.in-out]: copy each VAR_IN_OUT parameter back to the
    /// caller's variable after the call (copy-in, copy-out).
    fn write_back_in_out(
        &mut self,
        c: &Call,
        pou: &rootplc_sema::ir::Pou,
        frame: &Loc,
        span: Span,
        cx: &Ctx,
    ) -> R<()> {
        for (slot, ex) in &c.inputs {
            if pou.vars[*slot].section != Section::InOut
                || !matches!(
                    ex.kind,
                    ExprKind::Var(_)
                        | ExprKind::Global(_)
                        | ExprKind::Member(..)
                        | ExprKind::Index(..)
                        | ExprKind::Deref(_)
                )
            {
                continue;
            }
            let v = self.get(&frame.child(*slot), span)?.clone();
            let v = open_unwrap(&pou.vars[*slot].ty, &self.strip(&ex.ty), v);
            let target = self.place(ex, cx)?;
            self.store(&target, v, &ex.ty, ex.span)?;
        }
        Ok(())
    }

    fn call(&mut self, c: &Call, e: &Expr, cx: &Ctx) -> R<Value> {
        let prog = self.prog;
        match &c.target {
            CallTarget::Instance(inst, id) => {
                let loc = self.place(inst, cx)?;
                // [pous.oop.override]: a body called through a reference runs
                // the block of the instance itself, a derived one included
                let id = &match self.block_at(&loc) {
                    Some(d) if d != *id && self.extends(d, *id) => d,
                    _ => *id,
                };
                let Some(pou) = prog.pou(*id) else {
                    return Ok(Value::Int(0));
                };
                if pou.declare_only {
                    return Err(self.fault(
                        FaultKind::Unsupported,
                        e.span,
                        format!(
                            "{} is declared by a compatibility library but not implemented by RootPLC",
                            prog.defs[*id].name
                        ),
                    ));
                }
                for (slot, ex) in &c.inputs {
                    let v = self.eval(ex, cx)?;
                    let v = open_wrap(&pou.vars[*slot].ty, &self.strip(&ex.ty), v);
                    self.store(&loc.child(*slot), v, &pou.vars[*slot].ty, ex.span)?;
                }
                let mark = self.aliases.len();
                let al = self.in_out_aliases(c, pou, &loc, cx)?;
                self.aliases.extend(al);
                if pou.builtin {
                    self.native_fb(&prog.defs[*id].name, &loc, e.span)?;
                } else {
                    let saved = self.file;
                    self.file = prog.defs[*id].file;
                    let inner = Ctx {
                        this: loc.clone(),
                        inst: Some((loc.clone(), *id)),
                    };
                    self.exec_block(&pou.body, &inner)?;
                    self.file = saved;
                }
                self.aliases.truncate(mark);
                self.write_back_in_out(c, pou, &loc, e.span, cx)?;
                for (slot, target) in &c.outputs {
                    let v = self.get(&loc.child(*slot), e.span)?.clone();
                    let tl = self.place(target, cx)?;
                    self.store(&tl, v, &target.ty, target.span)?;
                }
                Ok(Value::Int(0))
            }
            CallTarget::Function(id) => self.call_frame(c, e, cx, *id, None),
            CallTarget::Method {
                inst,
                fb,
                method,
                name,
                dispatch,
            } => {
                let through_itf = prog
                    .pou(*fb)
                    .is_some_and(|p| p.kind == rootplc_sema::ir::PouKind::Interface);
                let (loc, rt) = if through_itf {
                    // [pous.oop.interface-ref]: the referenced instance and its block
                    match self.eval(inst, cx)? {
                        Value::Obj(Some((l, d))) => (l, d),
                        _ => {
                            return Err(self.fault(
                                FaultKind::NullRef,
                                inst.span,
                                format!("method {name} called through a NULL interface reference"),
                            ));
                        }
                    }
                } else {
                    // the instance's own type: for THIS, the block the caller runs on
                    let loc = self.place(inst, cx)?;
                    let rt = match &cx.inst {
                        Some((_, d)) if is_this_expr(inst) => *d,
                        _ => match self.block_at(&loc) {
                            Some(d) if *dispatch && d != *fb && self.extends(d, *fb) => d,
                            _ => *fb,
                        },
                    };
                    (loc, rt)
                };
                let m = if *dispatch {
                    prog.pou(rt)
                        .and_then(|p| p.methods.iter().find(|(n, _)| n.eq_ignore_ascii_case(name)))
                        .map_or(*method, |x| x.1)
                } else {
                    *method
                };
                self.call_frame(c, e, cx, m, Some((loc, rt)))
            }
            CallTarget::Builtin { name, ty } => {
                let mut args = Vec::with_capacity(c.args.len());
                for a in &c.args {
                    args.push(self.eval(a, cx)?);
                }
                self.builtin(name, ty.as_ref(), args, &c.args, e)
            }
        }
    }

    /// Run a function or method in a fresh frame; a method also gets the
    /// instance it runs on.
    fn call_frame(
        &mut self,
        c: &Call,
        e: &Expr,
        cx: &Ctx,
        id: usize,
        inst: Option<(Loc, usize)>,
    ) -> R<Value> {
        let prog = self.prog;
        if prog.pou(id).is_some_and(|p| p.declare_only) {
            return Err(self.fault(
                FaultKind::Unsupported,
                e.span,
                format!(
                    "{} is declared by a compatibility library but not implemented by RootPLC",
                    prog.defs[id].name
                ),
            ));
        }
        let Some(pou) = prog.pou(id) else {
            return Ok(Value::Int(0));
        };
        if self.roots.len() > MAX_DEPTH + 64 {
            return Err(self.fault(
                FaultKind::Watchdog,
                e.span,
                "call depth exceeded (recursion?)",
            ));
        }
        let mut vals = Vec::new();
        for (slot, ex) in &c.inputs {
            vals.push((*slot, self.eval(ex, cx)?, ex.span, self.strip(&ex.ty)));
        }
        let frame = self.default_named(id);
        self.roots.push(frame);
        self.root_defs.push(id);
        let root = self.roots.len() - 1;
        let floc = Loc {
            root,
            path: Vec::new(),
        };
        for (slot, v, span, aty) in vals {
            let v = open_wrap(&pou.vars[slot].ty, &aty, v);
            self.store(&floc.child(slot), v, &pou.vars[slot].ty, span)?;
        }
        let mark = self.aliases.len();
        let al = self.in_out_aliases(c, pou, &floc, cx)?;
        self.aliases.extend(al);
        let saved = self.file;
        self.file = prog.defs[id].file;
        self.exec_block(
            &pou.body,
            &Ctx {
                this: floc.clone(),
                inst,
            },
        )?;
        self.file = saved;
        self.aliases.truncate(mark);
        self.write_back_in_out(c, pou, &floc, e.span, cx)?;
        let result = if pou.ret.is_some() {
            self.get(&floc.child(pou.vars.len() - 1), e.span)?.clone()
        } else {
            Value::Int(0)
        };
        for (slot, target) in &c.outputs {
            let v = self.get(&floc.child(*slot), e.span)?.clone();
            let tl = self.place(target, cx)?;
            self.store(&tl, v, &target.ty, target.span)?;
        }
        self.roots.truncate(root);
        self.root_defs.truncate(root);
        Ok(result)
    }

    fn builtin(
        &mut self,
        name: &str,
        ty: Option<&Ty>,
        args: Vec<Value>,
        exprs: &[Expr],
        e: &Expr,
    ) -> R<Value> {
        let arg = |i: usize| args.get(i).cloned().unwrap_or(Value::Int(0));
        let out = |vm: &Self, v: Value| {
            vm.convert(v, &e.ty)
                .map_err(|k| vm.fault(k, e.span, "result outside the subrange"))
        };
        match name {
            // [types.time.arith]: a time of day, date or date-and-time with a
            // duration, or a difference; units: DATE / DT s, TOD / TIME ms,
            // L types ns
            "__ROOTPLC_TIME_ARITH" => {
                let (a, b, kind, sign) = (int(&arg(0)), int(&arg(1)), int(&arg(2)), int(&arg(3)));
                const DAY_MS: i128 = 86_400_000;
                const DAY_NS: i128 = 86_400_000_000_000;
                let n = match kind {
                    1 => (a + sign * b).rem_euclid(DAY_MS),
                    2 => a + sign * (b / 1000),
                    3 | 5 => (a - b) * 1000,
                    4 | 8 => a - b,
                    6 => (a + sign * b).rem_euclid(DAY_NS),
                    _ => a + sign * b,
                };
                out(self, Value::Int(n))
            }
            // [stdlib.compat.any]: (type class, reference, size); a value
            // that is not a variable gets a variable of its own
            "__ROOTPLC_ANY" => {
                let r = if int(&arg(3)) != 0 {
                    arg(0)
                } else {
                    let v = match ty {
                        Some(t) => self.convert(arg(0), t).unwrap_or_else(|_| arg(0)),
                        None => arg(0),
                    };
                    self.heap.push(Some(v));
                    Value::Ref(Some(Loc {
                        root: HEAP + self.heap.len() - 1,
                        path: Vec::new(),
                    }))
                };
                Ok(Value::Agg(vec![arg(1), r, arg(2)]))
            }
            // [stdlib.compat.query]
            "__QUERYINTERFACE" | "__QUERYPOINTER" => {
                let Value::Ref(Some(dl)) = arg(1) else {
                    return Ok(Value::Bool(false));
                };
                let obj = match arg(0) {
                    Value::Obj(Some(o)) => Some(o),
                    _ => None,
                };
                let (v, hit) = if name == "__QUERYINTERFACE" {
                    let itf = match ty {
                        Some(Ty::Named(t)) => Some(*t),
                        _ => None,
                    };
                    match (obj, itf) {
                        (Some((loc, d)), Some(t))
                            if self
                                .prog
                                .pou(d)
                                .is_some_and(|p| p.interfaces.binary_search(&t).is_ok()) =>
                        {
                            (Value::Obj(Some((loc, d))), true)
                        }
                        _ => (Value::Obj(None), false),
                    }
                } else {
                    match obj {
                        Some((loc, _)) => (Value::Ref(Some(loc)), true),
                        None => (Value::Ref(None), false),
                    }
                };
                *self.get_mut(&dl, e.span)? = v;
                Ok(Value::Bool(hit))
            }
            // [stdlib.compat.dynamic]
            "__NEW" => {
                let t = ty.cloned().unwrap_or(Ty::Unknown);
                let one = self.default_value(&t);
                let (v, path) = match args.first() {
                    Some(n) => {
                        let n = int(n).clamp(0, 1 << 20) as usize;
                        (Value::Agg(vec![one; n.max(1)]), vec![0])
                    }
                    None => (one, Vec::new()),
                };
                self.heap.push(Some(v));
                Ok(Value::Ref(Some(Loc {
                    root: HEAP + self.heap.len() - 1,
                    path,
                })))
            }
            "__DELETE" => {
                if let Value::Ref(Some(pl)) = arg(0) {
                    if let Ok(Value::Ref(Some(obj))) = self.get(&pl, e.span).cloned() {
                        if obj.root >= HEAP {
                            if let Some(slot) = self.heap.get_mut(obj.root - HEAP) {
                                *slot = None;
                            }
                        }
                    }
                    *self.get_mut(&pl, e.span)? = Value::Ref(None);
                }
                Ok(Value::Int(0))
            }
            // [stdlib.compat.intrinsics]: time since start, ms (virtual clock)
            "TIME" => Ok(Value::Int(self.now_ns / 1_000_000)),
            "ADVANCE" => {
                // [tests.time]: TIME is in ms, LTIME in ns.
                let n = int(&arg(0)).max(0);
                let ns = if ty.is_some_and(|t| *t == Ty::Elem(Elem::Ltime)) {
                    n
                } else {
                    n * 1_000_000
                };
                self.now_ns += ns;
                Ok(Value::Int(0))
            }
            "ASSERT_TRUE" | "ASSERT_FALSE" => {
                let want = name == "ASSERT_TRUE";
                if truthy(&arg(0)) != want {
                    let what = if want { "TRUE" } else { "FALSE" };
                    self.failures.push(AssertFailure {
                        file: self.file,
                        span: e.span,
                        message: format!("{name}: the condition is not {what}"),
                    });
                }
                Ok(Value::Int(0))
            }
            "ASSERT_EQ" | "ASSERT_NE" => {
                let t = ty.cloned().unwrap_or(Ty::Unknown);
                let (a, b) = (
                    self.convert(arg(0), &t).unwrap_or(arg(0)),
                    self.convert(arg(1), &t).unwrap_or(arg(1)),
                );
                let equal = compare(&a, &b) == Some(std::cmp::Ordering::Equal);
                if equal != (name == "ASSERT_EQ") {
                    let (da, db) = (self.display(&a, &t), self.display(&b, &t));
                    let message = if name == "ASSERT_EQ" {
                        format!("ASSERT_EQ: expected {da}, got {db}")
                    } else {
                        format!("ASSERT_NE: both are {da}")
                    };
                    self.failures.push(AssertFailure {
                        file: self.file,
                        span: e.span,
                        message,
                    });
                }
                Ok(Value::Int(0))
            }
            "TRUNC" => {
                let x = real(&arg(0));
                let n = if x.is_nan() { 0 } else { x.trunc() as i128 };
                let (lo, hi) = Elem::Dint.int_range().unwrap_or((0, 0));
                Ok(Value::Int(n.clamp(lo, hi)))
            }
            "ABS" => out(
                self,
                match arg(0) {
                    Value::Int(n) => Value::Int(n.abs()),
                    Value::Real(x) => Value::Real(x.abs()),
                    v => v,
                },
            ),
            "SQRT" | "LN" | "LOG" | "EXP" | "SIN" | "COS" | "TAN" | "ASIN" | "ACOS" | "ATAN" => {
                let x = real(&arg(0));
                let r = match name {
                    "SQRT" => x.sqrt(),
                    "LN" => x.ln(),
                    "LOG" => x.log10(),
                    "EXP" => x.exp(),
                    "SIN" => x.sin(),
                    "COS" => x.cos(),
                    "TAN" => x.tan(),
                    "ASIN" => x.asin(),
                    "ACOS" => x.acos(),
                    _ => x.atan(),
                };
                out(self, Value::Real(r))
            }
            "EXPT" => out(self, Value::Real(real(&arg(0)).powf(real(&arg(1))))),
            "MIN" | "MAX" | "MOVE" | "LIMIT" | "SEL" | "MUX" => {
                let pick = |a: Value, b: Value, max: bool| {
                    let gt = compare(&a, &b) == Some(std::cmp::Ordering::Greater);
                    if gt == max { a } else { b }
                };
                let v = match name {
                    "MOVE" => arg(0),
                    "MIN" => args
                        .iter()
                        .cloned()
                        .reduce(|a, b| pick(a, b, false))
                        .unwrap_or(Value::Int(0)),
                    "MAX" => args
                        .iter()
                        .cloned()
                        .reduce(|a, b| pick(a, b, true))
                        .unwrap_or(Value::Int(0)),
                    "LIMIT" => pick(arg(0), pick(arg(1), arg(2), false), true),
                    "SEL" => {
                        if truthy(&arg(0)) {
                            arg(2)
                        } else {
                            arg(1)
                        }
                    }
                    _ => {
                        let k = int(&arg(0));
                        match usize::try_from(k).ok().and_then(|k| args.get(k + 1)) {
                            Some(v) => v.clone(),
                            None => {
                                return Err(self.fault(
                                    FaultKind::Range,
                                    e.span,
                                    format!("MUX selector {k} out of range"),
                                ));
                            }
                        }
                    }
                };
                out(self, v)
            }
            "SHL" | "SHR" | "ROL" | "ROR" => {
                let el = self.elem(&e.ty).unwrap_or(Elem::Lword);
                let w = bit_width(el);
                let mask: i128 = (1i128 << w) - 1;
                let x = int(&arg(0)) & mask;
                let n = (int(&arg(1)).max(0) as u32) % 128;
                let r = match name {
                    "SHL" => (x << n.min(127)) & mask,
                    "SHR" => x >> n.min(127),
                    "ROL" => {
                        let n = n % w;
                        ((x << n) | (x >> ((w - n) % w))) & mask
                    }
                    _ => {
                        let n = n % w;
                        ((x >> n) | (x << ((w - n) % w))) & mask
                    }
                };
                Ok(Value::Int(wrap(r, el)))
            }
            "LEN" => Ok(Value::Int(to_text(&arg(0)).chars().count() as i128)),
            "LOWER_BOUND" | "UPPER_BOUND" => {
                // only open arrays reach the VM; others fold at compile time
                let d = int(&arg(1)).max(1) as usize;
                match open_header(&arg(0)).and_then(|h| h.get(d - 1).copied()) {
                    Some((lo, hi)) => Ok(Value::Int(if name == "LOWER_BOUND" { lo } else { hi })),
                    None => Err(self.fault(FaultKind::Unsupported, e.span, "array without bounds")),
                }
            }
            "FIND" => {
                let (a, b) = (to_text(&arg(0)), to_text(&arg(1)));
                let pos = a.find(&b).map_or(0, |byte| a[..byte].chars().count() + 1);
                Ok(Value::Int(pos as i128))
            }
            "CONCAT" | "LEFT" | "RIGHT" | "MID" | "INSERT" | "DELETE" | "REPLACE" => {
                let s: Vec<char> = to_text(&arg(0)).chars().collect();
                let n = |i: usize| usize::try_from(int(&arg(i)).max(0)).unwrap_or(0);
                let take =
                    |from: usize, len: usize| s.iter().skip(from).take(len).collect::<String>();
                let r = match name {
                    "CONCAT" => args.iter().map(to_text).collect(),
                    "LEFT" => take(0, n(1)),
                    "RIGHT" => take(s.len().saturating_sub(n(1)), n(1)),
                    "MID" => take(n(2).saturating_sub(1), n(1)),
                    "INSERT" => {
                        let p = n(2).min(s.len());
                        format!("{}{}{}", take(0, p), to_text(&arg(1)), take(p, s.len()))
                    }
                    "DELETE" => {
                        let p = n(2).saturating_sub(1);
                        format!("{}{}", take(0, p), take(p + n(1), s.len()))
                    }
                    _ => {
                        let p = n(3).saturating_sub(1);
                        format!(
                            "{}{}{}",
                            take(0, p),
                            to_text(&arg(1)),
                            take(p + n(2), s.len())
                        )
                    }
                };
                out(self, Value::Str(r))
            }
            _ => {
                // X_TO_Y and TO_Y, [types.conversion.explicit]
                let mut v = arg(0);
                if let Some(from) = ty {
                    v = self.convert(v, from).unwrap_or_else(|_| arg(0));
                }
                // to a STRING: the text of the value (INT_TO_STRING(42) = '42',
                // TIME_TO_STRING gives T#...ms); only a CHAR converts to its
                // character
                let from = ty.map(|t| self.strip(t));
                let to_str = matches!(self.strip(&e.ty), Ty::Str { .. });
                let chars = matches!(
                    from,
                    Some(Ty::Elem(Elem::Char | Elem::Wchar)) | Some(Ty::Str { .. })
                );
                if to_str && !chars && !matches!(v, Value::Str(_)) {
                    let text = match (&v, ty) {
                        (Value::Int(_), Some(t)) => self.display(&v, t),
                        _ => to_text(&v),
                    };
                    v = Value::Str(text);
                }
                // enumerations and BOOL convert by value
                let _ = exprs;
                out(self, v)
            }
        }
    }

    /// Standard function blocks, [stdlib.fbs]. Slots: declared inputs and
    /// outputs, then three state slots.
    fn native_fb(&mut self, name: &str, loc: &Loc, span: Span) -> R<()> {
        let mut s: Vec<Value> = match self.get(loc, span)? {
            Value::Agg(xs) => xs.clone(),
            _ => return Ok(()),
        };
        let b = |s: &[Value], i: usize| truthy(&s[i]);
        let n = |s: &[Value], i: usize| int(&s[i]);
        let now = self.now_ns;
        match name.to_ascii_uppercase().as_str() {
            "TON" => {
                // 0 IN, 1 PT, 2 Q, 3 ET | 4 -, 5 start, 6 running
                if b(&s, 0) {
                    if !b(&s, 6) {
                        s[6] = Value::Bool(true);
                        s[5] = Value::Int(now);
                    }
                    let et = (now - n(&s, 5)) / 1_000_000;
                    let pt = n(&s, 1);
                    s[2] = Value::Bool(et >= pt);
                    s[3] = Value::Int(et.min(pt));
                } else {
                    s[6] = Value::Bool(false);
                    s[2] = Value::Bool(false);
                    s[3] = Value::Int(0);
                }
            }
            "TOF" => {
                // 4 previous IN, 5 start
                if b(&s, 0) {
                    s[2] = Value::Bool(true);
                    s[3] = Value::Int(0);
                } else {
                    if b(&s, 4) {
                        s[5] = Value::Int(now);
                    }
                    if b(&s, 2) {
                        let et = (now - n(&s, 5)) / 1_000_000;
                        let pt = n(&s, 1);
                        s[2] = Value::Bool(et < pt);
                        s[3] = Value::Int(et.min(pt));
                    }
                }
                s[4] = Value::Bool(b(&s, 0));
            }
            "TP" => {
                // 4 previous IN, 5 start, 6 active
                if !b(&s, 6) && b(&s, 0) && !b(&s, 4) {
                    s[6] = Value::Bool(true);
                    s[5] = Value::Int(now);
                }
                if b(&s, 6) {
                    let et = (now - n(&s, 5)) / 1_000_000;
                    let pt = n(&s, 1);
                    if et >= pt {
                        s[6] = Value::Bool(false);
                        s[2] = Value::Bool(false);
                        s[3] = Value::Int(pt);
                    } else {
                        s[2] = Value::Bool(true);
                        s[3] = Value::Int(et);
                    }
                } else {
                    s[2] = Value::Bool(false);
                    if !b(&s, 0) {
                        s[3] = Value::Int(0);
                    }
                }
                s[4] = Value::Bool(b(&s, 0));
            }
            "R_TRIG" => {
                // 0 CLK, 1 Q | 2 memory
                s[1] = Value::Bool(b(&s, 0) && !b(&s, 2));
                s[2] = Value::Bool(b(&s, 0));
            }
            "F_TRIG" => {
                s[1] = Value::Bool(!b(&s, 0) && b(&s, 2));
                s[2] = Value::Bool(b(&s, 0));
            }
            "CTU" => {
                // 0 CU, 1 R, 2 PV, 3 Q, 4 CV | 5 previous CU
                if b(&s, 1) {
                    s[4] = Value::Int(0);
                } else if b(&s, 0) && !b(&s, 5) && n(&s, 4) < 32_767 {
                    s[4] = Value::Int(n(&s, 4) + 1);
                }
                s[3] = Value::Bool(n(&s, 4) >= n(&s, 2));
                s[5] = Value::Bool(b(&s, 0));
            }
            "CTD" => {
                // 0 CD, 1 LD, 2 PV, 3 Q, 4 CV | 5 previous CD
                if b(&s, 1) {
                    s[4] = Value::Int(n(&s, 2));
                } else if b(&s, 0) && !b(&s, 5) && n(&s, 4) > -32_768 {
                    s[4] = Value::Int(n(&s, 4) - 1);
                }
                s[3] = Value::Bool(n(&s, 4) <= 0);
                s[5] = Value::Bool(b(&s, 0));
            }
            "CTUD" => {
                // 0 CU, 1 CD, 2 R, 3 LD, 4 PV, 5 QU, 6 QD, 7 CV | 8 prev CU, 9 prev CD
                if b(&s, 2) {
                    s[7] = Value::Int(0);
                } else if b(&s, 3) {
                    s[7] = Value::Int(n(&s, 4));
                } else {
                    if b(&s, 0) && !b(&s, 8) && n(&s, 7) < 32_767 {
                        s[7] = Value::Int(n(&s, 7) + 1);
                    }
                    if b(&s, 1) && !b(&s, 9) && n(&s, 7) > -32_768 {
                        s[7] = Value::Int(n(&s, 7) - 1);
                    }
                }
                s[5] = Value::Bool(n(&s, 7) >= n(&s, 4));
                s[6] = Value::Bool(n(&s, 7) <= 0);
                s[8] = Value::Bool(b(&s, 0));
                s[9] = Value::Bool(b(&s, 1));
            }
            "SR" => s[2] = Value::Bool(b(&s, 0) || (!b(&s, 1) && b(&s, 2))),
            "RS" => s[2] = Value::Bool(!b(&s, 1) && (b(&s, 0) || b(&s, 2))),
            _ => {}
        }
        *self.get_mut(loc, span)? = Value::Agg(s);
        Ok(())
    }
}

fn const_value(c: &Const) -> Value {
    match c {
        Const::Bool(b) => Value::Bool(*b),
        Const::Int(n) => Value::Int(*n),
        Const::Real(x) => Value::Real(*x),
        Const::Str(s) => Value::Str(s.clone()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Compile `src`, run PROGRAM `p` for `cycles` cycles of `cycle_ms`.
    fn run(src: &str, cycles: usize, cycle_ms: i128) -> (Result<(), Fault>, Vec<(String, String)>) {
        let parse = rootplc_syntax::parse(src);
        assert!(parse.diagnostics.is_empty(), "{:?}", parse.diagnostics);
        let a = rootplc_sema::analyze(&[(&parse, src)]);
        assert!(a.ok(), "{:?}", a.diagnostics);
        let prog = a.program;
        let def = prog.find("p").expect("program p");
        let mut vm = Vm::new(&prog);
        let root = vm.instantiate(def);
        let mut res = Ok(());
        for _ in 0..cycles {
            res = vm.cycle(root, def);
            if res.is_err() {
                break;
            }
            vm.advance(cycle_ms * 1_000_000);
        }
        let pou = prog.pou(def).expect("pou");
        let vars = pou
            .vars
            .iter()
            .map(|v| {
                (
                    v.name.clone(),
                    vm.display(vm.read_var(root, def, &v.name).expect("var"), &v.ty),
                )
            })
            .collect();
        (res, vars)
    }

    fn var(vars: &[(String, String)], name: &str) -> String {
        vars.iter()
            .find(|(n, _)| n == name)
            .map(|(_, v)| v.clone())
            .unwrap_or_default()
    }

    fn fault(src: &str) -> FaultKind {
        run(src, 1, 0).0.expect_err("fault").kind
    }

    #[test]
    fn wraps_and_rounds() {
        let (r, v) = run(
            "PROGRAM p VAR x : SINT := 127; u : UDINT; r : REAL; d : LREAL; END_VAR
x := x + 1; u := u - 1; r := 0.1; d := r; END_PROGRAM",
            1,
            0,
        );
        assert!(r.is_ok());
        assert_eq!(var(&v, "x"), "-128");
        assert_eq!(var(&v, "u"), "4294967295");
        // REAL is binary32: 0.1 widened to LREAL shows the rounding.
        assert_eq!(var(&v, "d"), format!("{:?}", 0.1f32 as f64));
    }

    #[test]
    fn faults() {
        assert_eq!(
            fault("PROGRAM p VAR a, b : INT; END_VAR a := a / b; END_PROGRAM"),
            FaultKind::DivByZero
        );
        assert_eq!(
            fault(
                "PROGRAM p VAR a : ARRAY[0..2] OF INT; i : INT := 3; END_VAR a[i] := 1; END_PROGRAM"
            ),
            FaultKind::Index
        );
        assert_eq!(
            fault("PROGRAM p VAR r : REF_TO INT; END_VAR r^ := 1; END_PROGRAM"),
            FaultKind::NullRef
        );
        assert_eq!(
            fault(
                "TYPE Pct : INT (0..10); END_TYPE PROGRAM p VAR x : Pct; i : INT := 11; END_VAR x := i; END_PROGRAM"
            ),
            FaultKind::Range
        );
        assert_eq!(
            fault("PROGRAM p VAR b : BOOL := TRUE; END_VAR WHILE b DO ; END_WHILE; END_PROGRAM"),
            FaultKind::Watchdog
        );
    }

    #[test]
    fn ton_follows_the_virtual_clock() {
        let src = "PROGRAM p VAR t : TON; q : BOOL; et : TIME; END_VAR
t(IN := TRUE, PT := T#50ms, Q => q, ET => et); END_PROGRAM";
        let (_, v) = run(src, 3, 20); // calls at 0, 20, 40 ms
        assert_eq!(var(&v, "q"), "FALSE");
        assert_eq!(var(&v, "et"), "T#40ms");
        let (_, v) = run(src, 4, 20); // ... and 60 ms
        assert_eq!(var(&v, "q"), "TRUE");
        assert_eq!(var(&v, "et"), "T#50ms");
    }

    #[test]
    fn counters_and_edges() {
        let src = "PROGRAM p VAR c : CTU; e : R_TRIG; tick : BOOL; n : INT; rising : INT; END_VAR
tick := NOT tick; e(CLK := tick); IF e.Q THEN rising := rising + 1; END_IF;
c(CU := tick, PV := 3); n := c.CV; END_PROGRAM";
        let (_, v) = run(src, 6, 10);
        assert_eq!(var(&v, "rising"), "3");
        assert_eq!(var(&v, "n"), "3");
    }

    #[test]
    fn functions_strings_and_loops() {
        let src = "FUNCTION Fact : DINT VAR_INPUT n : DINT; END_VAR VAR i : DINT; END_VAR
Fact := 1; FOR i := 2 TO n DO Fact := Fact * i; END_FOR; END_FUNCTION
PROGRAM p VAR f : DINT; s : STRING[4]; k : INT; END_VAR
f := Fact(5); s := CONCAT('ab', 'cdef'); k := FIND('hello', 'll'); END_PROGRAM";
        let (r, v) = run(src, 1, 0);
        assert!(r.is_ok());
        assert_eq!(var(&v, "f"), "120");
        assert_eq!(var(&v, "s"), "'abcd'");
        assert_eq!(var(&v, "k"), "3");
    }
}
