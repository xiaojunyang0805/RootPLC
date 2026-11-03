//! The checker: name resolution and type checking over the syntax tree, and
//! emission of the typed IR (`ir.rs`).
//!
//! Passes: (1) register every type and POU name, (2) resolve types and POU
//! interfaces, (3) find structures that contain themselves, (4) check initial
//! values and statements, emitting IR. Expressions are typed bottom-up;
//! untyped literals take their type from the other operand or the assignment
//! target ([types.literal.untyped]). `Ty::Unknown` absorbs follow-on errors.

use std::collections::{HashMap, HashSet};

use rootplc_diag::{Code, Diagnostic, Span, codes};
use rootplc_syntax::{Element, Node, NodeKind as N, Token, TokenKind as T};

use crate::ir::{
    self, BinOp, CallTarget, CaseArm, Const, ExprKind, ForLoop, Init, PouKind, Section, Stmt, UnOp,
};
use crate::literal;
use crate::types::{DEFAULT_STRING_LEN, Elem, Ty};

const GENERIC_TYPES: &[&str] = &[
    "ANY",
    "ANY_DERIVED",
    "ANY_ELEMENTARY",
    "ANY_MAGNITUDE",
    "ANY_NUM",
    "ANY_REAL",
    "ANY_INT",
    "ANY_SIGNED",
    "ANY_UNSIGNED",
    "ANY_DURATION",
    "ANY_BIT",
    "ANY_CHARS",
    "ANY_STRING",
    "ANY_CHAR",
    "ANY_DATE",
];

#[derive(Clone, Copy)]
enum Item<'a> {
    Tok(usize),
    Node(&'a Node),
}

#[derive(Clone)]
struct Var<'a> {
    name: String,
    ty: Ty,
    section: Section,
    span: Span,
    init: Option<&'a Node>,
}

#[derive(Clone)]
struct Pou<'a> {
    kind: PouKind,
    vars: Vec<Var<'a>>,
    ret: Option<Ty>,
}

#[derive(Clone)]
enum Kind<'a> {
    Pending,
    Resolving,
    Alias(Ty),
    Struct(Vec<Var<'a>>),
    Enum(Vec<(String, i128)>),
    Subrange { base: Elem, lo: i128, hi: i128 },
    Pou(Pou<'a>),
}

#[derive(Clone)]
struct Def<'a> {
    name: String,
    file: usize,
    kind: Kind<'a>,
    node: Option<&'a Node>,
    span: Span,
    init: Option<&'a Node>,
}

/// A compile-time constant (for folding and range checks).
#[derive(Clone, Copy, PartialEq, Debug)]
enum K {
    Int(i128),
    Real(f64),
    Bool(bool),
    Str(usize),
}

/// A typed expression with its IR.
#[derive(Clone, Debug)]
struct V {
    ty: Ty,
    k: Option<K>,
    /// A literal, possibly negated: out of range is RP0102, not RP0101.
    leaf: bool,
    span: Span,
    e: ExprKind,
}

impl V {
    fn of(ty: Ty, span: Span) -> V {
        V {
            ty,
            k: None,
            leaf: false,
            span,
            e: ExprKind::Invalid,
        }
    }
    fn unknown(span: Span) -> V {
        V::of(Ty::Unknown, span)
    }
    fn with(ty: Ty, span: Span, e: ExprKind) -> V {
        V {
            ty,
            k: None,
            leaf: false,
            span,
            e,
        }
    }
    /// The IR of this value; folded constants become `Const`.
    fn ir(self) -> ir::Expr {
        let kind = match self.k {
            Some(K::Int(n)) => ExprKind::Const(Const::Int(n)),
            Some(K::Real(x)) => ExprKind::Const(Const::Real(x)),
            Some(K::Bool(b)) => ExprKind::Const(Const::Bool(b)),
            _ => self.e,
        };
        ir::Expr {
            ty: self.ty,
            kind,
            span: self.span,
        }
    }
}

enum Fold {
    Ok(K),
    Overflow,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Cls {
    Arith,
    Mod,
    Pow,
    Cmp,
    Logic,
}

enum Builtin {
    Advance,
    AssertBool,
    AssertCmp,
    Conv(Ty, Ty),
    ToConv(Ty),
    Trunc,
    SameAsArg,
    Common,
    Sel,
    Mux,
    StrInt,
    StrFn,
}

struct Arg<'a> {
    /// Name token and whether it is an output binding (`=>`).
    name: Option<(usize, bool)>,
    expr: &'a Node,
}

/// IR collected for a definition in pass 4.
#[derive(Default)]
struct DefIr {
    var_inits: Vec<Option<Init>>,
    body: Vec<Stmt>,
}

pub(crate) struct Checker<'a> {
    /// Source text and tokens of every file in the project.
    files: Vec<(&'a str, &'a [Token])>,
    /// File whose tokens are being read.
    cur: usize,
    defs: Vec<Def<'a>>,
    types: HashMap<String, usize>,
    scope: Option<usize>,
    irs: HashMap<usize, DefIr>,
    /// Diagnostics with the index of their file.
    pub(crate) diags: Vec<(usize, Diagnostic)>,
}

fn is_trivia(k: T) -> bool {
    k.is_trivia() || k == T::Pragma
}

fn elem_or_str(name: &str) -> Option<Ty> {
    match name.to_ascii_uppercase().as_str() {
        "STRING" => Some(Ty::Str {
            wide: false,
            len: DEFAULT_STRING_LEN,
        }),
        "WSTRING" => Some(Ty::Str {
            wide: true,
            len: DEFAULT_STRING_LEN,
        }),
        n => Elem::from_name(n).map(Ty::Elem),
    }
}

fn builtin(up: &str) -> Option<Builtin> {
    use Builtin::*;
    Some(match up {
        "ADVANCE" => Advance,
        "ASSERT_TRUE" | "ASSERT_FALSE" => AssertBool,
        "ASSERT_EQ" | "ASSERT_NE" => AssertCmp,
        "TRUNC" => Trunc,
        "ABS" | "SQRT" | "LN" | "LOG" | "EXP" | "SIN" | "COS" | "TAN" | "ASIN" | "ACOS"
        | "ATAN" | "EXPT" | "SHL" | "SHR" | "ROL" | "ROR" => SameAsArg,
        "MIN" | "MAX" | "MOVE" | "LIMIT" => Common,
        "SEL" => Sel,
        "MUX" => Mux,
        "LEN" | "FIND" => StrInt,
        "LEFT" | "RIGHT" | "MID" | "CONCAT" | "INSERT" | "DELETE" | "REPLACE" => StrFn,
        _ => {
            if let Some((a, b)) = up.split_once("_TO_") {
                return Some(Conv(elem_or_str(a)?, elem_or_str(b)?));
            }
            return up.strip_prefix("TO_").and_then(elem_or_str).map(ToConv);
        }
    })
}

impl<'a> Checker<'a> {
    pub(crate) fn new(files: Vec<(&'a str, &'a [Token])>) -> Self {
        let mut c = Checker {
            files,
            cur: 0,
            defs: Vec::new(),
            types: HashMap::new(),
            scope: None,
            irs: HashMap::new(),
            diags: Vec::new(),
        };
        // [stdlib.fbs]
        use Elem::{Bool, Int, Time};
        for t in ["TON", "TOF", "TP"] {
            c.builtin_fb(
                t,
                &[("IN", Bool), ("PT", Time)],
                &[("Q", Bool), ("ET", Time)],
            );
        }
        for t in ["R_TRIG", "F_TRIG"] {
            c.builtin_fb(t, &[("CLK", Bool)], &[("Q", Bool)]);
        }
        c.builtin_fb(
            "CTU",
            &[("CU", Bool), ("R", Bool), ("PV", Int)],
            &[("Q", Bool), ("CV", Int)],
        );
        c.builtin_fb(
            "CTD",
            &[("CD", Bool), ("LD", Bool), ("PV", Int)],
            &[("Q", Bool), ("CV", Int)],
        );
        c.builtin_fb(
            "CTUD",
            &[
                ("CU", Bool),
                ("CD", Bool),
                ("R", Bool),
                ("LD", Bool),
                ("PV", Int),
            ],
            &[("QU", Bool), ("QD", Bool), ("CV", Int)],
        );
        c.builtin_fb("SR", &[("S1", Bool), ("R", Bool)], &[("Q1", Bool)]);
        c.builtin_fb("RS", &[("S", Bool), ("R1", Bool)], &[("Q1", Bool)]);
        c
    }

    fn builtin_fb(&mut self, name: &str, inputs: &[(&str, Elem)], outputs: &[(&str, Elem)]) {
        let var = |(n, e): &(&str, Elem), section| Var {
            name: (*n).to_string(),
            ty: Ty::Elem(*e),
            section,
            span: Span::new(0, 0),
            init: None,
        };
        let mut vars: Vec<Var<'a>> = inputs.iter().map(|x| var(x, Section::Input)).collect();
        vars.extend(outputs.iter().map(|x| var(x, Section::Output)));
        let pou = Pou {
            kind: PouKind::FunctionBlock,
            vars,
            ret: None,
        };
        self.add_def(name, Kind::Pou(pou), None, Span::new(0, 0));
    }

    fn add_def(&mut self, name: &str, kind: Kind<'a>, node: Option<&'a Node>, span: Span) -> usize {
        let key = name.to_ascii_lowercase();
        if let Some(&prev) = self.types.get(&key) {
            // Standard blocks (no source node) may be replaced, [stdlib.fbs].
            if self.defs[prev].node.is_some() {
                self.diag(
                    codes::DUPLICATE_NAME,
                    format!("'{name}' is already declared as a type or POU"),
                    span,
                    None,
                );
            }
        }
        let id = self.defs.len();
        self.defs.push(Def {
            name: name.to_string(),
            file: self.cur,
            kind,
            node,
            span,
            init: None,
        });
        self.types.insert(key, id);
        id
    }

    pub(crate) fn run(&mut self, roots: &[&'a Node]) {
        for (f, root) in roots.iter().enumerate() {
            self.cur = f;
            self.collect(root);
        }
        for id in 0..self.defs.len() {
            self.resolve(id);
        }
        self.check_recursion();
        for id in 0..self.defs.len() {
            self.check_def(id);
        }
    }

    /// The typed IR of the project.
    pub(crate) fn into_program(mut self) -> ir::Program {
        let mut defs = Vec::with_capacity(self.defs.len());
        for (id, d) in self.defs.iter().enumerate() {
            let mut irs = self.irs.remove(&id).unwrap_or_default();
            let mut inits = std::mem::take(&mut irs.var_inits).into_iter();
            let mut var = |v: &Var<'a>| ir::Var {
                name: v.name.clone(),
                ty: v.ty.clone(),
                section: v.section,
                init: inits.next().flatten(),
            };
            let kind = match &d.kind {
                Kind::Pending | Kind::Resolving => ir::DefKind::Unresolved,
                Kind::Alias(t) => ir::DefKind::Alias(t.clone()),
                Kind::Struct(m) => ir::DefKind::Struct(m.iter().map(&mut var).collect()),
                Kind::Enum(v) => ir::DefKind::Enum(v.clone()),
                Kind::Subrange { base, lo, hi } => ir::DefKind::Subrange {
                    base: *base,
                    lo: *lo,
                    hi: *hi,
                },
                Kind::Pou(p) => {
                    let mut vars: Vec<ir::Var> = p.vars.iter().map(&mut var).collect();
                    if let (PouKind::Function, Some(t)) = (p.kind, &p.ret) {
                        vars.push(ir::Var {
                            name: d.name.clone(),
                            ty: t.clone(),
                            section: Section::Result,
                            init: None,
                        });
                    }
                    ir::DefKind::Pou(ir::Pou {
                        kind: p.kind,
                        vars,
                        ret: p.ret.clone(),
                        body: std::mem::take(&mut irs.body),
                        builtin: d.node.is_none(),
                    })
                }
            };
            defs.push(ir::Def {
                name: d.name.clone(),
                file: d.file,
                kind,
            });
        }
        ir::Program { defs }
    }

    // ---------------------------------------------------------------- tree access

    fn toks(&self) -> &'a [Token] {
        self.files[self.cur].1
    }

    fn src(&self) -> &'a str {
        self.files[self.cur].0
    }

    fn items(&self, n: &'a Node) -> Vec<Item<'a>> {
        n.children
            .iter()
            .filter_map(|c| match c {
                Element::Node(x) => Some(Item::Node(x)),
                Element::Token(i) if !is_trivia(self.toks()[*i].kind) => Some(Item::Tok(*i)),
                Element::Token(_) => None,
            })
            .collect()
    }

    fn child_nodes(&self, n: &'a Node, kind: N) -> Vec<&'a Node> {
        n.nodes(kind).collect()
    }

    fn first_node(&self, n: &'a Node) -> Option<&'a Node> {
        self.items(n).into_iter().find_map(|i| match i {
            Item::Node(x) => Some(x),
            Item::Tok(_) => None,
        })
    }

    fn text(&self, i: usize) -> &'a str {
        self.toks()[i].text(self.src())
    }

    fn tkind(&self, i: usize) -> T {
        self.toks()[i].kind
    }

    fn is_kw(&self, i: usize, kw: &str) -> bool {
        self.tkind(i) == T::Keyword && self.text(i).eq_ignore_ascii_case(kw)
    }

    fn tok_span(&self, i: usize) -> Span {
        self.toks()[i].span
    }

    fn edge_tok(&self, n: &Node, last: bool) -> Option<usize> {
        let mut it: Box<dyn Iterator<Item = &Element>> = if last {
            Box::new(n.children.iter().rev())
        } else {
            Box::new(n.children.iter())
        };
        it.find_map(|c| match c {
            Element::Token(i) if !is_trivia(self.toks()[*i].kind) => Some(*i),
            Element::Token(_) => None,
            Element::Node(x) => self.edge_tok(x, last),
        })
    }

    fn span(&self, n: &Node) -> Span {
        match (self.edge_tok(n, false), self.edge_tok(n, true)) {
            (Some(a), Some(b)) => Span::new(
                self.toks()[a].span.start as usize,
                self.toks()[b].span.end as usize,
            ),
            _ => Span::new(0, 0),
        }
    }

    // ---------------------------------------------------------------- diagnostics

    fn diag(&mut self, code: Code, msg: String, span: Span, hint: Option<String>) {
        let mut d = Diagnostic::new(code, msg, span);
        if let Some(h) = hint {
            d = d.with_hint(h);
        }
        self.diags.push((self.cur, d));
    }

    fn ty_name(&self, t: &Ty) -> String {
        match t {
            Ty::Elem(e) => e.name().to_string(),
            Ty::Str { wide, len } => {
                let base = if *wide { "WSTRING" } else { "STRING" };
                if *len == DEFAULT_STRING_LEN {
                    base.to_string()
                } else {
                    format!("{base}[{len}]")
                }
            }
            Ty::Array { elem, .. } => format!("ARRAY OF {}", self.ty_name(elem)),
            Ty::Ref(t) => format!("REF_TO {}", self.ty_name(t)),
            Ty::Named(i) => self.defs[*i].name.clone(),
            Ty::IntLit => "integer literal".into(),
            Ty::RealLit => "real literal".into(),
            Ty::Null => "NULL".into(),
            Ty::Unknown => "?".into(),
        }
    }

    // ---------------------------------------------------------------- pass 1: collect

    fn collect(&mut self, root: &'a Node) {
        for it in self.items(root) {
            let Item::Node(n) = it else { continue };
            match n.kind {
                N::TypeBlock => {
                    for d in self.child_nodes(n, N::TypeDecl) {
                        if let Some(Item::Tok(t)) = self.items(d).first().copied() {
                            if self.tkind(t) == T::Ident {
                                let span = self.tok_span(t);
                                self.add_def(self.text(t), Kind::Pending, Some(d), span);
                            }
                        }
                    }
                }
                N::Program | N::Function | N::FunctionBlock | N::Test => {
                    if let Some(Item::Tok(t)) = self.items(n).get(1).copied() {
                        if self.tkind(t) == T::Ident {
                            let span = self.tok_span(t);
                            self.add_def(self.text(t), Kind::Pending, Some(n), span);
                        }
                    }
                }
                _ => {}
            }
        }
    }

    // ---------------------------------------------------------------- pass 2: resolve

    fn resolve(&mut self, id: usize) {
        if !matches!(self.defs[id].kind, Kind::Pending) {
            return;
        }
        let saved = self.cur;
        self.cur = self.defs[id].file;
        self.resolve_in_file(id);
        self.cur = saved;
    }

    fn resolve_in_file(&mut self, id: usize) {
        let Some(node) = self.defs[id].node else {
            return;
        };
        self.defs[id].kind = Kind::Resolving;
        if node.kind == N::TypeDecl {
            let its = self.items(node);
            let find = |k: N| {
                its.iter().find_map(|i| match i {
                    Item::Node(n) if n.kind == k => Some(*n),
                    _ => None,
                })
            };
            self.defs[id].init = find(N::Initializer);
            let ty = find(N::TypeSpec).map_or(Ty::Unknown, |s| self.type_spec(s, Some(id)));
            if matches!(self.defs[id].kind, Kind::Resolving) {
                self.defs[id].kind = Kind::Alias(ty);
            }
            return;
        }
        let kind = match node.kind {
            N::Program => PouKind::Program,
            N::Function => PouKind::Function,
            N::FunctionBlock => PouKind::FunctionBlock,
            _ => PouKind::Test,
        };
        let (mut vars, mut ret) = (Vec::new(), None);
        for it in self.items(node) {
            let Item::Node(n) = it else { continue };
            match n.kind {
                N::TypeSpec => ret = Some(self.type_spec(n, None)),
                N::VarSection => {
                    let section = match self.items(n).first() {
                        Some(Item::Tok(t)) => match self.text(*t).to_ascii_uppercase().as_str() {
                            "VAR_INPUT" => Section::Input,
                            "VAR_OUTPUT" => Section::Output,
                            "VAR_IN_OUT" => Section::InOut,
                            _ => Section::Local,
                        },
                        _ => Section::Local,
                    };
                    for d in self.child_nodes(n, N::VarDecl) {
                        self.var_decl(d, section, &mut vars);
                    }
                }
                _ => {}
            }
        }
        self.defs[id].kind = Kind::Pou(Pou { kind, vars, ret });
    }

    fn var_decl(&mut self, d: &'a Node, section: Section, out: &mut Vec<Var<'a>>) {
        let its = self.items(d);
        let mut names = Vec::new();
        let (mut spec, mut init) = (None, None);
        let mut before_colon = true;
        for it in &its {
            match *it {
                Item::Tok(t) if self.tkind(t) == T::Colon => before_colon = false,
                Item::Tok(t) if before_colon && self.tkind(t) == T::Ident => names.push(t),
                Item::Node(n) if n.kind == N::TypeSpec => spec = Some(n),
                Item::Node(n) if n.kind == N::Initializer => init = Some(n),
                _ => {}
            }
        }
        let ty = spec.map_or(Ty::Unknown, |s| self.type_spec(s, None));
        if init.is_none() {
            init = spec.and_then(|s| self.type_default(s));
        }
        for t in names {
            out.push(Var {
                name: self.text(t).to_string(),
                ty: ty.clone(),
                section,
                span: self.tok_span(t),
                init,
            });
        }
    }

    /// Initial value given in the declaration of a named type in this file,
    /// such as `TYPE Speed : INT := 10; END_TYPE`, [types.derived.alias].
    fn type_default(&self, spec: &'a Node) -> Option<&'a Node> {
        let its = self.items(spec);
        let [Item::Tok(t)] = its.as_slice() else {
            return None;
        };
        if self.tkind(*t) != T::Ident {
            return None;
        }
        let &id = self.types.get(&self.text(*t).to_ascii_lowercase())?;
        let d = &self.defs[id];
        if d.file == self.cur { d.init } else { None }
    }

    /// A reference to a named type; aliases resolve to their target.
    fn named_ref(&mut self, id: usize) -> Ty {
        if matches!(self.defs[id].kind, Kind::Pending) {
            self.resolve(id);
        }
        match &self.defs[id].kind {
            Kind::Alias(t) => t.clone(),
            _ => Ty::Named(id),
        }
    }

    /// Store a structure, enumeration or subrange: in the declaration being
    /// resolved, or as an anonymous type.
    fn make_def(&mut self, decl: Option<usize>, kind: Kind<'a>) -> Ty {
        if let Some(id) = decl {
            if matches!(self.defs[id].kind, Kind::Resolving) {
                self.defs[id].kind = kind;
                return Ty::Named(id);
            }
        }
        let id = self.defs.len();
        self.defs.push(Def {
            name: "<anonymous>".into(),
            file: self.cur,
            kind,
            node: None,
            span: Span::new(0, 0),
            init: None,
        });
        Ty::Named(id)
    }

    /// [pous.type-spec], [types.derived.*].
    fn type_spec(&mut self, n: &'a Node, decl: Option<usize>) -> Ty {
        let its = self.items(n);
        let Some(first) = its.first().copied() else {
            return Ty::Unknown;
        };
        match first {
            Item::Tok(i) if self.tkind(i) == T::TypeName => {
                let mut ty = elem_or_str(self.text(i)).unwrap_or(Ty::Unknown);
                let mut k = 1;
                while k < its.len() {
                    match its[k] {
                        Item::Tok(t) if self.tkind(t) == T::LBracket => {
                            if let (Some(Item::Node(e)), Ty::Str { wide, .. }) =
                                (its.get(k + 1).copied(), ty.clone())
                            {
                                match self.const_int(e) {
                                    Some(v) if (1..=65_535).contains(&v) => {
                                        ty = Ty::Str {
                                            wide,
                                            len: v as u32,
                                        }
                                    }
                                    Some(v) => {
                                        let sp = self.span(e);
                                        let msg = format!("string length {v} is outside 1..65535");
                                        self.diag(codes::INVALID_BOUNDS, msg, sp, None);
                                    }
                                    None => {}
                                }
                            }
                            k += 3;
                        }
                        Item::Tok(t) if self.tkind(t) == T::LParen => {
                            if let (Some(Item::Node(l)), Some(Item::Node(h))) =
                                (its.get(k + 1).copied(), its.get(k + 3).copied())
                            {
                                if let (Ty::Elem(base), Some(a), Some(b)) =
                                    (ty.clone(), self.const_int(l), self.const_int(h))
                                {
                                    if a > b {
                                        let sp = Span::new(
                                            self.span(l).start as usize,
                                            self.span(h).end as usize,
                                        );
                                        let msg = format!(
                                            "subrange {a}..{b}: the lower bound exceeds the upper bound"
                                        );
                                        self.diag(codes::INVALID_BOUNDS, msg, sp, None);
                                    } else {
                                        ty = self
                                            .make_def(decl, Kind::Subrange { base, lo: a, hi: b });
                                    }
                                }
                            }
                            k += 5;
                        }
                        Item::Node(e) if e.kind == N::EnumType => {
                            ty = self.enum_type(e, decl);
                            k += 1;
                        }
                        _ => k += 1,
                    }
                }
                ty
            }
            Item::Tok(i) if self.tkind(i) == T::Ident => self.type_name(i),
            Item::Tok(i) if self.is_kw(i, "REF_TO") => match its.get(1).copied() {
                Some(Item::Node(s)) => Ty::Ref(Box::new(self.type_spec(s, None))),
                _ => Ty::Unknown,
            },
            Item::Node(e) => match e.kind {
                N::EnumType => self.enum_type(e, decl),
                N::ArrayType => self.array_type(e),
                N::StructType => {
                    let mut members = Vec::new();
                    for d in self.child_nodes(e, N::VarDecl) {
                        self.var_decl(d, Section::Local, &mut members);
                    }
                    self.make_def(decl, Kind::Struct(members))
                }
                _ => Ty::Unknown,
            },
            Item::Tok(_) => Ty::Unknown,
        }
    }

    fn type_name(&mut self, i: usize) -> Ty {
        let name = self.text(i);
        let span = self.tok_span(i);
        if let Some(&id) = self.types.get(&name.to_ascii_lowercase()) {
            if matches!(&self.defs[id].kind, Kind::Pou(p) if p.kind == PouKind::Function) {
                self.diag(
                    codes::UNKNOWN_TYPE,
                    format!("'{name}' is a function, not a type"),
                    span,
                    None,
                );
                return Ty::Unknown;
            }
            return self.named_ref(id);
        }
        if GENERIC_TYPES.iter().any(|g| g.eq_ignore_ascii_case(name)) {
            self.diag(
                codes::GENERIC_TYPE_IN_DECLARATION,
                format!("generic type '{name}' can only appear in standard-library signatures"),
                span,
                Some("use a concrete type such as INT or REAL".into()),
            );
        } else {
            self.diag(
                codes::UNKNOWN_TYPE,
                format!("unknown type '{name}'"),
                span,
                None,
            );
        }
        Ty::Unknown
    }

    fn enum_type(&mut self, e: &'a Node, decl: Option<usize>) -> Ty {
        let mut values = Vec::new();
        let mut next = 0i128;
        for v in self.child_nodes(e, N::EnumValue) {
            let Some(Item::Tok(t)) = self.items(v).first().copied() else {
                continue;
            };
            let explicit = self.first_node(v).and_then(|x| self.const_int(x));
            let val = explicit.unwrap_or(next);
            values.push((self.text(t).to_string(), val));
            next = val + 1;
        }
        self.make_def(decl, Kind::Enum(values))
    }

    fn array_type(&mut self, e: &'a Node) -> Ty {
        let mut dims = Vec::new();
        let mut elem = Ty::Unknown;
        for it in self.items(e) {
            let Item::Node(n) = it else { continue };
            match n.kind {
                N::ArrayDim => {
                    let parts: Vec<&Node> = self
                        .items(n)
                        .into_iter()
                        .filter_map(|i| match i {
                            Item::Node(x) => Some(x),
                            Item::Tok(_) => None,
                        })
                        .collect();
                    let dim = match parts.as_slice() {
                        [l, h] => match (self.const_int(l), self.const_int(h)) {
                            (Some(a), Some(b)) if a > b => {
                                let sp = self.span(n);
                                let msg = format!(
                                    "array bounds {a}..{b}: the lower bound exceeds the upper bound"
                                );
                                self.diag(codes::INVALID_BOUNDS, msg, sp, None);
                                None
                            }
                            (Some(a), Some(b)) => Some((a, b)),
                            _ => None,
                        },
                        _ => None,
                    };
                    dims.push(dim);
                }
                N::TypeSpec => elem = self.type_spec(n, None),
                _ => {}
            }
        }
        Ty::Array {
            dims,
            elem: Box::new(elem),
        }
    }

    /// Constant integer value of a simple expression (literals, sign, + - * /).
    fn const_int(&self, n: &'a Node) -> Option<i128> {
        let its = self.items(n);
        match n.kind {
            N::Literal => match its.first().copied() {
                Some(Item::Tok(i)) => match self.tkind(i) {
                    T::Integer => literal::parse_int(self.text(i)),
                    T::TypedLiteral => literal::parse_int(self.text(i).split_once('#')?.1),
                    _ => None,
                },
                _ => None,
            },
            N::ParenExpr => self.const_int(self.first_node(n)?),
            N::UnaryExpr => match (its.first().copied(), its.get(1).copied()) {
                (Some(Item::Tok(op)), Some(Item::Node(x))) => match self.tkind(op) {
                    T::Minus => self.const_int(x).map(|v| -v),
                    T::Plus => self.const_int(x),
                    _ => None,
                },
                _ => None,
            },
            N::BinExpr => match (
                its.first().copied(),
                its.get(1).copied(),
                its.get(2).copied(),
            ) {
                (Some(Item::Node(l)), Some(Item::Tok(op)), Some(Item::Node(r))) => {
                    let (a, b) = (self.const_int(l)?, self.const_int(r)?);
                    match self.tkind(op) {
                        T::Plus => a.checked_add(b),
                        T::Minus => a.checked_sub(b),
                        T::Star => a.checked_mul(b),
                        T::Slash => a.checked_div(b),
                        _ => None,
                    }
                }
                _ => None,
            },
            _ => None,
        }
    }

    // ---------------------------------------------------------------- pass 3: recursion

    fn contains(&self, ty: &Ty, target: usize, seen: &mut HashSet<usize>) -> bool {
        match ty {
            Ty::Named(i) => {
                if *i == target {
                    return true;
                }
                if !seen.insert(*i) {
                    return false;
                }
                match &self.defs[*i].kind {
                    Kind::Struct(m) => m.iter().any(|v| self.contains(&v.ty, target, seen)),
                    _ => false,
                }
            }
            Ty::Array { elem, .. } => self.contains(elem, target, seen),
            _ => false,
        }
    }

    /// [types.derived.struct]: RP0107.
    fn check_recursion(&mut self) {
        for id in 0..self.defs.len() {
            let Kind::Struct(members) = &self.defs[id].kind else {
                continue;
            };
            let mut seen = HashSet::new();
            if members.iter().any(|v| self.contains(&v.ty, id, &mut seen)) {
                let name = self.defs[id].name.clone();
                let span = self.defs[id].span;
                self.cur = self.defs[id].file;
                self.diag(
                    codes::RECURSIVE_STRUCT,
                    format!("structure '{name}' contains itself"),
                    span,
                    Some(format!("use REF_TO {name} to link to another instance")),
                );
            }
        }
    }

    // ---------------------------------------------------------------- pass 4: bodies

    fn check_def(&mut self, id: usize) {
        let d = self.defs[id].clone();
        self.cur = d.file;
        let mut out = DefIr::default();
        match &d.kind {
            Kind::Alias(t) => {
                // The value becomes the default of variables of this type
                // (see `type_default`); here it is only checked.
                if let Some(i) = d.init {
                    self.scope = None;
                    self.initializer(t, i);
                }
            }
            Kind::Struct(members) => {
                self.scope = None;
                for v in members {
                    let init = v.init.and_then(|i| self.initializer(&v.ty, i));
                    out.var_inits.push(init);
                }
            }
            Kind::Pou(p) => {
                let Some(node) = d.node else { return };
                self.scope = Some(id);
                let mut seen = HashSet::new();
                for v in &p.vars {
                    if !seen.insert(v.name.to_ascii_lowercase()) {
                        let msg = format!("'{}' is already declared in {}", v.name, d.name);
                        self.diag(codes::DUPLICATE_NAME, msg, v.span, None);
                    }
                }
                for v in &p.vars {
                    let init = v.init.and_then(|i| self.initializer(&v.ty, i));
                    out.var_inits.push(init);
                }
                for s in self.child_nodes(node, N::StmtList) {
                    out.body = self.stmt_list(s);
                }
                self.scope = None;
            }
            _ => return,
        }
        self.irs.insert(id, out);
    }

    /// [variables.initializer.check].
    fn initializer(&mut self, ty: &Ty, n: &'a Node) -> Option<Init> {
        let inner = self.first_node(n)?;
        let span = self.span(inner);
        match inner.kind {
            N::ArrayInit => {
                let elem = match self.strip(ty) {
                    Ty::Array { elem, .. } => *elem,
                    Ty::Unknown => return None,
                    _ => {
                        let msg =
                            format!("array initializer for a value of type {}", self.ty_name(ty));
                        self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                        return None;
                    }
                };
                let items = self
                    .child_nodes(inner, N::Initializer)
                    .into_iter()
                    .filter_map(|c| self.initializer(&elem, c))
                    .collect();
                Some(Init::Array(items))
            }
            N::StructInit => {
                let members = match ty {
                    Ty::Named(i) => match &self.defs[*i].kind {
                        Kind::Struct(m) => m.clone(),
                        _ => Vec::new(),
                    },
                    Ty::Unknown => return None,
                    _ => Vec::new(),
                };
                if members.is_empty() {
                    let msg = format!(
                        "structure initializer for a value of type {}",
                        self.ty_name(ty)
                    );
                    self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                    return None;
                }
                let mut fields = Vec::new();
                let mut cur = None;
                for it in self.items(inner) {
                    match it {
                        Item::Tok(t) if self.tkind(t) == T::Ident => cur = Some(t),
                        Item::Node(c) if c.kind == N::Initializer => {
                            let Some(t) = cur.take() else { continue };
                            let name = self.text(t);
                            match members
                                .iter()
                                .position(|m| m.name.eq_ignore_ascii_case(name))
                            {
                                Some(k) => {
                                    if let Some(i) = self.initializer(&members[k].ty, c) {
                                        fields.push((k, i));
                                    }
                                }
                                None => {
                                    let msg = format!(
                                        "structure {} has no member '{name}'",
                                        self.ty_name(ty)
                                    );
                                    let sp = self.tok_span(t);
                                    self.diag(codes::UNKNOWN_NAME, msg, sp, None);
                                }
                            }
                        }
                        _ => {}
                    }
                }
                Some(Init::Struct(fields))
            }
            _ => {
                let v = self.expr(inner);
                self.coerce(ty, &v);
                Some(Init::Expr(v.ir()))
            }
        }
    }

    fn stmt_list(&mut self, n: &'a Node) -> Vec<Stmt> {
        let mut out = Vec::new();
        for it in self.items(n) {
            if let Item::Node(s) = it {
                if let Some(st) = self.stmt(s) {
                    out.push(st);
                }
            }
        }
        out
    }

    fn stmt(&mut self, n: &'a Node) -> Option<Stmt> {
        let its = self.items(n);
        match n.kind {
            N::AssignStmt => {
                let (Some(Item::Node(t)), Some(Item::Tok(op)), Some(Item::Node(e))) = (
                    its.first().copied(),
                    its.get(1).copied(),
                    its.get(2).copied(),
                ) else {
                    return None;
                };
                let target = self.expr(t);
                let value = self.expr(e);
                if self.tkind(op) == T::Assign {
                    self.coerce(&target.ty, &value);
                }
                Some(Stmt::Assign(target.ir(), value.ir()))
            }
            N::CallStmt => self.first_node(n).map(|c| Stmt::Eval(self.expr(c).ir())),
            N::IfStmt => {
                let mut arms = Vec::new();
                let mut cond: Option<ir::Expr> = None;
                let mut want_cond = false;
                let mut else_body = Vec::new();
                for it in its {
                    match it {
                        Item::Tok(t) if self.is_kw(t, "IF") || self.is_kw(t, "ELSIF") => {
                            want_cond = true
                        }
                        Item::Node(c) if c.kind == N::StmtList => {
                            let body = self.stmt_list(c);
                            match cond.take() {
                                Some(e) => arms.push((e, body)),
                                None => else_body = body,
                            }
                        }
                        Item::Node(c) if want_cond => {
                            cond = Some(self.condition(c));
                            want_cond = false;
                        }
                        _ => {}
                    }
                }
                Some(Stmt::If(arms, else_body))
            }
            N::CaseStmt => {
                let mut sel: Option<V> = None;
                let mut arms = Vec::new();
                let mut default = Vec::new();
                for it in its {
                    let Item::Node(c) = it else { continue };
                    match c.kind {
                        N::CaseElement => arms.push(self.case_element(c, sel.as_ref())),
                        N::StmtList => default = self.stmt_list(c),
                        _ if sel.is_none() => sel = Some(self.expr(c)),
                        _ => {}
                    }
                }
                let sel = sel?;
                Some(Stmt::Case {
                    sel: sel.ir(),
                    arms,
                    default,
                })
            }
            N::ForStmt => {
                let mut ctrl = V::unknown(self.span(n));
                if let Some(Item::Tok(t)) = its.get(1).copied() {
                    let name = self.text(t);
                    let span = self.tok_span(t);
                    match self.lookup_var(name) {
                        Some((ty, slot)) => {
                            let ok = match self.strip(&ty) {
                                Ty::Elem(e) => e.is_int(),
                                Ty::Unknown => true,
                                _ => false,
                            };
                            if !ok {
                                let msg = format!(
                                    "FOR control variable '{name}' must be an integer, not {}",
                                    self.ty_name(&ty)
                                );
                                self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                            }
                            ctrl = V::with(
                                if ok { ty } else { Ty::Unknown },
                                span,
                                ExprKind::Var(slot),
                            );
                        }
                        None => {
                            self.diag(
                                codes::UNKNOWN_NAME,
                                format!("unknown name '{name}'"),
                                span,
                                None,
                            );
                        }
                    }
                }
                let mut exprs = Vec::new();
                let mut body = Vec::new();
                for it in its {
                    let Item::Node(c) = it else { continue };
                    if c.kind == N::StmtList {
                        body = self.stmt_list(c);
                    } else {
                        let v = self.expr(c);
                        self.coerce(&ctrl.ty, &v);
                        exprs.push(v.ir());
                    }
                }
                let mut ex = exprs.into_iter();
                let (from, to) = (ex.next()?, ex.next()?);
                Some(Stmt::For(Box::new(ForLoop {
                    var: ctrl.ir(),
                    from,
                    to,
                    by: ex.next(),
                    body,
                })))
            }
            N::WhileStmt | N::RepeatStmt => {
                let (mut cond, mut body) = (None, Vec::new());
                for it in its {
                    let Item::Node(c) = it else { continue };
                    if c.kind == N::StmtList {
                        body = self.stmt_list(c);
                    } else {
                        cond = Some(self.condition(c));
                    }
                }
                let cond = cond?;
                Some(if n.kind == N::WhileStmt {
                    Stmt::While(cond, body)
                } else {
                    Stmt::Repeat(body, cond)
                })
            }
            N::ExitStmt => Some(Stmt::Exit),
            N::ContinueStmt => Some(Stmt::Continue),
            N::ReturnStmt => Some(Stmt::Return),
            _ => None,
        }
    }

    fn case_element(&mut self, c: &'a Node, sel: Option<&V>) -> CaseArm {
        let its = self.items(c);
        let mut ranges = Vec::new();
        let mut body = Vec::new();
        let mut k = 0;
        while k < its.len() {
            match its[k] {
                Item::Node(e) if e.kind == N::StmtList => body = self.stmt_list(e),
                Item::Node(e) => {
                    let lo = self.label(e, sel);
                    let mut hi = lo;
                    if let (Some(Item::Tok(t)), Some(Item::Node(e2))) =
                        (its.get(k + 1).copied(), its.get(k + 2).copied())
                    {
                        if self.tkind(t) == T::DotDot {
                            hi = self.label(e2, sel);
                            k += 2;
                        }
                    }
                    if let (Some(a), Some(b)) = (lo, hi) {
                        ranges.push((a, b));
                    }
                }
                Item::Tok(_) => {}
            }
            k += 1;
        }
        CaseArm {
            labels: ranges,
            body,
        }
    }

    fn label(&mut self, e: &'a Node, sel: Option<&V>) -> Option<i128> {
        let v = self.expr(e);
        if let Some(s) = sel {
            let st = s.ty.clone();
            self.coerce(&st, &v);
        }
        match v.k {
            Some(K::Int(n)) => Some(n),
            _ => None,
        }
    }

    /// Conditions are `BOOL`, with no implicit conversion, [statements.if].
    fn condition(&mut self, c: &'a Node) -> ir::Expr {
        let v = self.expr(c);
        self.coerce(&Ty::Elem(Elem::Bool), &v);
        v.ir()
    }

    // ---------------------------------------------------------------- names

    /// Variable of the current POU: type and frame slot.
    fn lookup_var(&self, name: &str) -> Option<(Ty, usize)> {
        let id = self.scope?;
        let Kind::Pou(p) = &self.defs[id].kind else {
            return None;
        };
        if let Some(i) = p
            .vars
            .iter()
            .position(|v| v.name.eq_ignore_ascii_case(name))
        {
            return Some((p.vars[i].ty.clone(), i));
        }
        if p.kind == PouKind::Function && self.defs[id].name.eq_ignore_ascii_case(name) {
            return p.ret.clone().map(|t| (t, p.vars.len()));
        }
        None
    }

    fn scope_kind(&self) -> Option<PouKind> {
        match &self.defs[self.scope?].kind {
            Kind::Pou(p) => Some(p.kind),
            _ => None,
        }
    }

    /// Bare enumeration value, [types.derived.enum].
    fn enum_value(&mut self, name: &str, span: Span) -> Option<V> {
        let hits: Vec<(usize, i128)> = self
            .defs
            .iter()
            .enumerate()
            .filter_map(|(id, d)| match &d.kind {
                Kind::Enum(vals) => vals
                    .iter()
                    .find(|(n, _)| n.eq_ignore_ascii_case(name))
                    .map(|(_, v)| (id, *v)),
                _ => None,
            })
            .collect();
        match hits.as_slice() {
            [] => None,
            [(id, v)] => Some(V {
                ty: Ty::Named(*id),
                k: Some(K::Int(*v)),
                leaf: true,
                span,
                e: ExprKind::Invalid,
            }),
            many => {
                let names: Vec<String> = many
                    .iter()
                    .map(|(id, _)| self.defs[*id].name.clone())
                    .collect();
                let hint = format!("write {}#{name}", names[0]);
                let msg = format!(
                    "'{name}' is a value of several enumerations ({})",
                    names.join(", ")
                );
                self.diag(codes::AMBIGUOUS_ENUM_VALUE, msg, span, Some(hint));
                Some(V::unknown(span))
            }
        }
    }

    // ---------------------------------------------------------------- types

    /// Subrange types behave as their base type, with bounds.
    fn base_range(&self, t: &Ty) -> (Ty, Option<(i128, i128)>) {
        if let Ty::Named(id) = t {
            if let Kind::Subrange { base, lo, hi } = self.defs[*id].kind {
                return (Ty::Elem(base), Some((lo, hi)));
            }
        }
        (t.clone(), None)
    }

    fn strip(&self, t: &Ty) -> Ty {
        self.base_range(t).0
    }

    fn is_enum(&self, t: &Ty) -> bool {
        matches!(t, Ty::Named(i) if matches!(self.defs[*i].kind, Kind::Enum(_)))
    }

    /// [types.conversion.implicit], [types.equivalence], [types.derived.alias].
    fn compatible(&self, to: &Ty, from: &Ty) -> bool {
        let (to, from) = (self.strip(to), self.strip(from));
        match (&to, &from) {
            (Ty::Unknown, _) | (_, Ty::Unknown) => true,
            (Ty::Elem(a), Ty::Elem(b)) => b.widens_to(*a),
            (Ty::Str { wide: a, .. }, Ty::Str { wide: b, .. }) => a == b,
            (Ty::Str { wide: false, .. }, Ty::Elem(Elem::Char))
            | (Ty::Str { wide: true, .. }, Ty::Elem(Elem::Wchar)) => true,
            (Ty::Named(a), Ty::Named(b)) => a == b,
            (Ty::Ref(a), Ty::Ref(b)) => self.compatible(a, b) && self.compatible(b, a),
            (Ty::Array { dims: da, elem: ea }, Ty::Array { dims: db, elem: eb }) => {
                (da == db || da.iter().all(Option::is_none))
                    && self.compatible(ea, eb)
                    && self.compatible(eb, ea)
            }
            _ => false,
        }
    }

    fn mismatch(&mut self, to: &Ty, v: &V) {
        let (from_n, to_n) = (self.ty_name(&v.ty), self.ty_name(to));
        let (fb, tb) = (self.strip(&v.ty), self.strip(to));
        let hint = match (&fb, &tb) {
            (Ty::Elem(a), Ty::Elem(b)) => Some(format!(
                "use {}_TO_{}(...) to convert explicitly",
                a.name(),
                b.name()
            )),
            (Ty::IntLit, Ty::Elem(b)) if b.is_duration() => {
                Some("write a duration literal such as T#500ms".into())
            }
            (_, Ty::Elem(b)) if self.is_enum(&fb) => Some(format!("use TO_{}(...)", b.name())),
            _ => None,
        };
        self.diag(
            codes::IMPLICIT_CONVERSION,
            format!("{from_n} does not convert implicitly to {to_n}"),
            v.span,
            hint,
        );
    }

    /// Check that `v` may be stored in `to`. Reports and returns false if not.
    fn coerce(&mut self, to: &Ty, v: &V) -> bool {
        if matches!(to, Ty::Unknown) || matches!(v.ty, Ty::Unknown) {
            return true;
        }
        let (tb, range) = self.base_range(to);
        match &v.ty {
            Ty::IntLit => {
                return match &tb {
                    Ty::Elem(e) if e.is_real() => true,
                    Ty::Elem(e) if e.int_range().is_some() => {
                        let (Some(K::Int(n)), Some((lo, hi))) = (v.k, e.int_range()) else {
                            return true;
                        };
                        if n < lo || n > hi {
                            let (code, what) = if v.leaf {
                                (codes::LITERAL_OUT_OF_RANGE, "literal")
                            } else {
                                (codes::CONSTANT_OVERFLOW, "constant expression")
                            };
                            let msg = format!("{what} {n} does not fit {} ({lo}..{hi})", e.name());
                            self.diag(code, msg, v.span, None);
                            return false;
                        }
                        self.in_range(to, n, range, v.span)
                    }
                    _ => {
                        self.mismatch(to, v);
                        false
                    }
                };
            }
            Ty::RealLit => {
                let ok = matches!(tb, Ty::Elem(e) if e.is_real());
                if !ok {
                    self.mismatch(to, v);
                }
                return ok;
            }
            Ty::Null => {
                let ok = matches!(tb, Ty::Ref(_));
                if !ok {
                    self.mismatch(to, v);
                }
                return ok;
            }
            _ => {}
        }
        if matches!(tb, Ty::Elem(Elem::Char | Elem::Wchar)) && v.k == Some(K::Str(1)) {
            return true;
        }
        if !self.compatible(to, &v.ty) {
            self.mismatch(to, v);
            return false;
        }
        if let Some(K::Int(n)) = v.k {
            if !self.in_range(to, n, range, v.span) {
                return false;
            }
        }
        if let (Ty::Str { len, .. }, Some(K::Str(n))) = (&tb, v.k) {
            if n > *len as usize {
                let msg = format!(
                    "string of {n} characters is longer than {}; it will be truncated",
                    self.ty_name(to)
                );
                self.diag(codes::STRING_LITERAL_TOO_LONG, msg, v.span, None);
            }
        }
        true
    }

    /// [types.derived.subrange]: RP0105.
    fn in_range(&mut self, to: &Ty, n: i128, range: Option<(i128, i128)>, span: Span) -> bool {
        if let Some((a, b)) = range {
            if n < a || n > b {
                let msg = format!(
                    "{n} is outside the subrange {a}..{b} of {}",
                    self.ty_name(to)
                );
                self.diag(codes::OUTSIDE_SUBRANGE, msg, span, None);
                return false;
            }
        }
        true
    }

    /// Common type of two operands; reports RP0103 if there is none.
    fn unify(&mut self, l: &V, r: &V, what: &str) -> Ty {
        let (lt, rt) = (self.strip(&l.ty), self.strip(&r.ty));
        match (&lt, &rt) {
            (Ty::Unknown, _) | (_, Ty::Unknown) => Ty::Unknown,
            (Ty::IntLit, Ty::IntLit) => Ty::IntLit,
            (Ty::IntLit | Ty::RealLit, Ty::RealLit) | (Ty::RealLit, Ty::IntLit) => Ty::RealLit,
            (Ty::IntLit | Ty::RealLit | Ty::Null, _) => {
                if self.coerce(&rt, l) {
                    rt
                } else {
                    Ty::Unknown
                }
            }
            (_, Ty::IntLit | Ty::RealLit | Ty::Null) => {
                if self.coerce(&lt, r) {
                    lt
                } else {
                    Ty::Unknown
                }
            }
            _ if self.compatible(&rt, &lt) => rt,
            _ if self.compatible(&lt, &rt) => lt,
            _ => {
                let msg = format!(
                    "operands of {what} have incompatible types {} and {}",
                    self.ty_name(&l.ty),
                    self.ty_name(&r.ty)
                );
                let span = Span::new(l.span.start as usize, r.span.end as usize);
                let hint =
                    Some("convert one operand explicitly, for example with TO_INT(...)".into());
                self.diag(codes::IMPLICIT_CONVERSION, msg, span, hint);
                Ty::Unknown
            }
        }
    }

    // ---------------------------------------------------------------- expressions

    fn expr(&mut self, n: &'a Node) -> V {
        let span = self.span(n);
        let its = self.items(n);
        match n.kind {
            N::Literal => match its.first().copied() {
                Some(Item::Tok(i)) => self.literal(i),
                _ => V::unknown(span),
            },
            N::NameRef => match its.first().copied() {
                Some(Item::Tok(i)) => {
                    let name = self.text(i);
                    if let Some((t, slot)) = self.lookup_var(name) {
                        return V::with(t, span, ExprKind::Var(slot));
                    }
                    if let Some(v) = self.enum_value(name, span) {
                        return v;
                    }
                    let hint = Some("declare it in a VAR section of this POU".into());
                    self.diag(
                        codes::UNKNOWN_NAME,
                        format!("unknown name '{name}'"),
                        span,
                        hint,
                    );
                    V::unknown(span)
                }
                _ => V::unknown(span),
            },
            N::ParenExpr => match self.first_node(n) {
                Some(x) => {
                    let mut v = self.expr(x);
                    v.span = span;
                    v
                }
                None => V::unknown(span),
            },
            N::UnaryExpr => self.unary(&its, span),
            N::BinExpr => self.binary(&its, span),
            N::MemberExpr => self.member(&its, span),
            N::IndexExpr => self.index(&its, span),
            N::DerefExpr => match self.first_node(n) {
                Some(b) => {
                    let base = self.expr(b);
                    match base.ty.clone() {
                        Ty::Ref(t) => V::with(*t, span, ExprKind::Deref(Box::new(base.ir()))),
                        _ => V::unknown(span),
                    }
                }
                None => V::unknown(span),
            },
            N::RefExpr => match self.first_node(n) {
                Some(x) => {
                    let v = self.expr(x);
                    V::with(
                        Ty::Ref(Box::new(v.ty.clone())),
                        span,
                        ExprKind::Ref(Box::new(v.ir())),
                    )
                }
                None => V::unknown(span),
            },
            N::CallExpr => match (its.first().copied(), its.get(1).copied()) {
                (Some(Item::Node(callee)), Some(Item::Node(args))) => self.call(callee, args, span),
                _ => V::unknown(span),
            },
            _ => V::unknown(span),
        }
    }

    fn literal(&mut self, i: usize) -> V {
        let text = self.text(i);
        let span = self.tok_span(i);
        let up = text.to_ascii_uppercase();
        let lit = |ty, k, e| V {
            ty,
            k,
            leaf: true,
            span,
            e,
        };
        let int = |e: Elem, v: Option<i128>| V {
            ty: Ty::Elem(e),
            k: None,
            leaf: true,
            span,
            e: v.map_or(ExprKind::Invalid, |v| ExprKind::Const(Const::Int(v))),
        };
        match self.tkind(i) {
            T::Integer => match literal::parse_int(text) {
                Some(v) => lit(Ty::IntLit, Some(K::Int(v)), ExprKind::Invalid),
                None => V::unknown(span),
            },
            T::Real => lit(
                Ty::RealLit,
                literal::parse_real(text).map(K::Real),
                ExprKind::Invalid,
            ),
            T::TypedLiteral => self.typed_literal(text, span),
            T::Duration => {
                let ns = literal::duration_ns(text);
                if up.starts_with("LT") {
                    int(Elem::Ltime, ns)
                } else {
                    int(Elem::Time, ns.map(|n| n / 1_000_000))
                }
            }
            T::Date => {
                let days = literal::date_value(text).map(i128::from);
                if up.starts_with("LD") {
                    int(Elem::Ldate, days.map(|d| d * 86_400 * 1_000_000_000))
                } else {
                    int(Elem::Date, days.map(|d| d * 86_400))
                }
            }
            T::TimeOfDay => {
                let ns = literal::tod_value(text);
                if up.starts_with("LT") {
                    int(Elem::Ltod, ns)
                } else {
                    int(Elem::Tod, ns.map(|n| n / 1_000_000))
                }
            }
            T::DateAndTime => {
                let ns = literal::dt_value(text);
                if up.starts_with("LD") {
                    int(Elem::Ldt, ns)
                } else {
                    int(Elem::Dt, ns.map(|n| n / 1_000_000_000))
                }
            }
            T::Char => {
                let wide = up.starts_with('W');
                let q = text.split_once('#').map_or(text, |(_, b)| b);
                let code = literal::decode_str(q, wide)
                    .chars()
                    .next()
                    .map(|c| i128::from(c as u32));
                int(if wide { Elem::Wchar } else { Elem::Char }, code)
            }
            T::String | T::WString => {
                let wide = self.tkind(i) == T::WString;
                let s = literal::decode_str(text, wide);
                let n = s.chars().count();
                lit(
                    Ty::Str {
                        wide,
                        len: n as u32,
                    },
                    Some(K::Str(n)),
                    ExprKind::Const(Const::Str(s)),
                )
            }
            T::EnumLiteral => self.enum_literal(text, span),
            T::DirectVariable => {
                let mut cs = text.trim_start_matches('%').chars().skip(1);
                let e = match cs.next().map(|c| c.to_ascii_uppercase()) {
                    Some('X') => Elem::Bool,
                    Some('B') => Elem::Byte,
                    Some('W') => Elem::Word,
                    Some('D') => Elem::Dword,
                    Some('L') => Elem::Lword,
                    Some(c) if c.is_ascii_digit() => Elem::Bool,
                    _ => return V::unknown(span),
                };
                V::of(Ty::Elem(e), span)
            }
            T::Keyword => match up.as_str() {
                "TRUE" => lit(Ty::Elem(Elem::Bool), Some(K::Bool(true)), ExprKind::Invalid),
                "FALSE" => lit(
                    Ty::Elem(Elem::Bool),
                    Some(K::Bool(false)),
                    ExprKind::Invalid,
                ),
                "NULL" => lit(Ty::Null, None, ExprKind::Null),
                _ => V::unknown(span),
            },
            _ => V::unknown(span),
        }
    }

    /// `INT#5`, `BYTE#16#FF`, `BOOL#1`, `REAL#1.5`, `STRING#'x'`; [types.literal.range].
    fn typed_literal(&mut self, text: &str, span: Span) -> V {
        let Some((p, rest)) = text.split_once('#') else {
            return V::unknown(span);
        };
        let up = p.to_ascii_uppercase();
        if up == "STRING" || up == "WSTRING" {
            let wide = up == "WSTRING";
            let s = literal::decode_str(rest, wide);
            let n = s.chars().count();
            return V {
                ty: Ty::Str {
                    wide,
                    len: n as u32,
                },
                k: Some(K::Str(n)),
                leaf: true,
                span,
                e: ExprKind::Const(Const::Str(s)),
            };
        }
        let Some(e) = Elem::from_name(&up) else {
            return V::unknown(span);
        };
        let ty = Ty::Elem(e);
        let mk = |k| V {
            ty: ty.clone(),
            k,
            leaf: true,
            span,
            e: ExprKind::Invalid,
        };
        if e == Elem::Bool {
            return mk(match rest.to_ascii_uppercase().as_str() {
                "1" | "TRUE" => Some(K::Bool(true)),
                "0" | "FALSE" => Some(K::Bool(false)),
                _ => None,
            });
        }
        if let Some((lo, hi)) = e.int_range() {
            if let Some(v) = literal::parse_int(rest) {
                if v < lo || v > hi {
                    let msg = format!("literal {v} does not fit {} ({lo}..{hi})", e.name());
                    self.diag(codes::LITERAL_OUT_OF_RANGE, msg, span, None);
                    return V::of(ty, span);
                }
                return mk(Some(K::Int(v)));
            }
        }
        if e.is_real() {
            return mk(literal::parse_real(rest).map(K::Real));
        }
        V::of(ty, span)
    }

    /// `Mode#Auto`.
    fn enum_literal(&mut self, text: &str, span: Span) -> V {
        let Some((t, val)) = text.split_once('#') else {
            return V::unknown(span);
        };
        let Some(&id) = self.types.get(&t.to_ascii_lowercase()) else {
            self.diag(
                codes::UNKNOWN_TYPE,
                format!("unknown type '{t}'"),
                span,
                None,
            );
            return V::unknown(span);
        };
        let Kind::Enum(vals) = &self.defs[id].kind else {
            self.diag(
                codes::UNKNOWN_TYPE,
                format!("'{t}' is not an enumeration"),
                span,
                None,
            );
            return V::unknown(span);
        };
        match vals.iter().find(|(n, _)| n.eq_ignore_ascii_case(val)) {
            Some((_, v)) => V {
                ty: Ty::Named(id),
                k: Some(K::Int(*v)),
                leaf: true,
                span,
                e: ExprKind::Invalid,
            },
            None => {
                self.diag(
                    codes::UNKNOWN_NAME,
                    format!("enumeration '{t}' has no value '{val}'"),
                    span,
                    None,
                );
                V::unknown(span)
            }
        }
    }

    fn unary(&mut self, its: &[Item<'a>], span: Span) -> V {
        let (Some(Item::Tok(op)), Some(Item::Node(x))) =
            (its.first().copied(), its.get(1).copied())
        else {
            return V::unknown(span);
        };
        let v = self.expr(x);
        let st = self.strip(&v.ty);
        let optext = self.text(op).to_ascii_uppercase();
        if optext == "NOT" {
            let ok =
                matches!(st, Ty::IntLit | Ty::Unknown) || matches!(st, Ty::Elem(e) if e.is_bit());
            if !ok {
                let msg = format!(
                    "operator NOT needs BOOL or a bit string, found {}",
                    self.ty_name(&v.ty)
                );
                self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                return V::unknown(span);
            }
            let k = match v.k {
                Some(K::Bool(b)) => Some(K::Bool(!b)),
                _ => None,
            };
            let ty = v.ty.clone();
            return V {
                ty,
                k,
                leaf: false,
                span,
                e: ExprKind::Unary(UnOp::Not, Box::new(v.ir())),
            };
        }
        let ok = matches!(st, Ty::IntLit | Ty::RealLit | Ty::Unknown)
            || matches!(st, Ty::Elem(e) if e.is_num() || e.is_duration());
        if !ok {
            let msg = format!(
                "operator '{optext}' needs a numeric operand, found {}",
                self.ty_name(&v.ty)
            );
            self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
            return V::unknown(span);
        }
        if optext != "-" {
            let mut v = v;
            v.span = span;
            return v;
        }
        let k = match v.k {
            Some(K::Int(x)) => Some(K::Int(-x)),
            Some(K::Real(x)) => Some(K::Real(-x)),
            _ => None,
        };
        let leaf = v.leaf;
        V {
            ty: st,
            k,
            leaf,
            span,
            e: ExprKind::Unary(UnOp::Neg, Box::new(v.ir())),
        }
    }

    fn binary(&mut self, its: &[Item<'a>], span: Span) -> V {
        let (Some(Item::Node(ln)), Some(Item::Tok(op)), Some(Item::Node(rn))) = (
            its.first().copied(),
            its.get(1).copied(),
            its.get(2).copied(),
        ) else {
            return V::unknown(span);
        };
        let l = self.expr(ln);
        let r = self.expr(rn);
        let opk = self.tkind(op);
        let opt = self.text(op).to_ascii_uppercase();
        let (cls, bop) = match opk {
            T::Plus => (Cls::Arith, BinOp::Add),
            T::Minus => (Cls::Arith, BinOp::Sub),
            T::Star => (Cls::Arith, BinOp::Mul),
            T::Slash => (Cls::Arith, BinOp::Div),
            T::Power => (Cls::Pow, BinOp::Pow),
            T::Eq => (Cls::Cmp, BinOp::Eq),
            T::Neq => (Cls::Cmp, BinOp::Ne),
            T::Lt => (Cls::Cmp, BinOp::Lt),
            T::Gt => (Cls::Cmp, BinOp::Gt),
            T::Le => (Cls::Cmp, BinOp::Le),
            T::Ge => (Cls::Cmp, BinOp::Ge),
            T::Ampersand => (Cls::Logic, BinOp::And),
            _ => match opt.as_str() {
                "MOD" => (Cls::Mod, BinOp::Mod),
                "AND" => (Cls::Logic, BinOp::And),
                "AND_THEN" => (Cls::Logic, BinOp::AndThen),
                "OR" => (Cls::Logic, BinOp::Or),
                "OR_ELSE" => (Cls::Logic, BinOp::OrElse),
                _ => (Cls::Logic, BinOp::Xor),
            },
        };
        // [types.int.division]: constant divisor zero.
        if (opk == T::Slash || cls == Cls::Mod) && r.k == Some(K::Int(0)) {
            let hint = Some("the divisor is the constant 0".into());
            self.diag(
                codes::CONSTANT_OVERFLOW,
                "division by zero in a constant expression".into(),
                r.span,
                hint,
            );
            return V::of(self.strip(&l.ty), span);
        }
        let mk = |ty: Ty, opty: Ty, l: V, r: V| {
            let e = ExprKind::Binary {
                op: bop,
                opty,
                l: Box::new(l.ir()),
                r: Box::new(r.ir()),
            };
            V::with(ty, span, e)
        };
        // Duration scaled by an integer.
        if matches!(opk, T::Star | T::Slash) {
            let (lt, rt) = (self.strip(&l.ty), self.strip(&r.ty));
            if matches!(lt, Ty::Elem(e) if e.is_duration())
                && (matches!(rt, Ty::IntLit) || matches!(rt, Ty::Elem(e) if e.is_int()))
            {
                return mk(lt.clone(), lt, l, r);
            }
        }
        let what = format!("'{}'", self.text(op));
        let ty = self.unify(&l, &r, &what);
        if ty == Ty::Unknown {
            return V::unknown(span);
        }
        let st = self.strip(&ty);
        let num = matches!(st, Ty::IntLit | Ty::RealLit) || matches!(st, Ty::Elem(e) if e.is_num());
        let ok = match cls {
            Cls::Arith => {
                num || (matches!(st, Ty::Elem(e) if e.is_duration())
                    && matches!(opk, T::Plus | T::Minus))
            }
            Cls::Mod => matches!(st, Ty::IntLit) || matches!(st, Ty::Elem(e) if e.is_int()),
            Cls::Pow => num,
            Cls::Cmp => true,
            Cls::Logic => matches!(st, Ty::IntLit) || matches!(st, Ty::Elem(e) if e.is_bit()),
        };
        if !ok {
            let msg = format!("operator {what} is not defined for {}", self.ty_name(&ty));
            self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
            return V::unknown(span);
        }
        let rty = if cls == Cls::Cmp {
            Ty::Elem(Elem::Bool)
        } else {
            st.clone()
        };
        let k = match (l.k, r.k) {
            (Some(a), Some(b)) => match fold(cls, opk, &opt, a, b) {
                Some(Fold::Ok(k)) => Some(k),
                Some(Fold::Overflow) => {
                    self.diag(
                        codes::CONSTANT_OVERFLOW,
                        "constant expression overflows".into(),
                        span,
                        None,
                    );
                    return V::of(rty, span);
                }
                None => None,
            },
            _ => None,
        };
        if let (Some(K::Int(v)), Ty::Elem(e)) = (k, &rty) {
            if let Some((lo, hi)) = e.int_range() {
                if v < lo || v > hi {
                    let msg = format!(
                        "constant expression {v} overflows {} ({lo}..{hi})",
                        e.name()
                    );
                    self.diag(codes::CONSTANT_OVERFLOW, msg, span, None);
                    return V::of(rty, span);
                }
            }
        }
        let mut out = mk(rty, st, l, r);
        out.k = k;
        out
    }

    fn member(&mut self, its: &[Item<'a>], span: Span) -> V {
        let (Some(Item::Node(b)), Some(Item::Tok(m))) = (its.first().copied(), its.get(2).copied())
        else {
            return V::unknown(span);
        };
        let base = self.expr(b);
        let bt = self.strip(&base.ty);
        if self.tkind(m) == T::Integer {
            // bit access x.3
            return match (bt, literal::parse_int(self.text(m))) {
                (Ty::Elem(e), Some(n)) if e.is_bit() || e.is_int() => V::with(
                    Ty::Elem(Elem::Bool),
                    span,
                    ExprKind::Bit(Box::new(base.ir()), n as u32),
                ),
                _ => V::unknown(span),
            };
        }
        let name = self.text(m);
        let Ty::Named(id) = bt else {
            return V::unknown(span);
        };
        let tname = self.defs[id].name.clone();
        // [tests.whitebox]: TEST blocks may read every variable of an instance.
        let whitebox = self.scope_kind() == Some(PouKind::Test);
        let found = match &self.defs[id].kind {
            Kind::Struct(ms) => Some(
                ms.iter()
                    .position(|v| v.name.eq_ignore_ascii_case(name))
                    .map(|i| (i, ms[i].ty.clone())),
            ),
            Kind::Pou(p) => Some(
                p.vars
                    .iter()
                    .position(|v| {
                        (whitebox || v.section != Section::Local)
                            && v.name.eq_ignore_ascii_case(name)
                    })
                    .map(|i| (i, p.vars[i].ty.clone())),
            ),
            _ => None,
        };
        match found {
            Some(Some((i, t))) => V::with(t, span, ExprKind::Member(Box::new(base.ir()), i)),
            Some(None) => {
                let what = if matches!(self.defs[id].kind, Kind::Struct(_)) {
                    "member"
                } else {
                    "input or output"
                };
                let sp = self.tok_span(m);
                self.diag(
                    codes::UNKNOWN_NAME,
                    format!("'{tname}' has no {what} '{name}'"),
                    sp,
                    None,
                );
                V::unknown(span)
            }
            None => V::unknown(span),
        }
    }

    fn index(&mut self, its: &[Item<'a>], span: Span) -> V {
        let Some(Item::Node(b)) = its.first().copied() else {
            return V::unknown(span);
        };
        let base = self.expr(b);
        let mut idx = Vec::new();
        for it in &its[1..] {
            if let Item::Node(e) = *it {
                let v = self.expr(e);
                let st = self.strip(&v.ty);
                let ok = matches!(st, Ty::IntLit | Ty::Unknown)
                    || matches!(st, Ty::Elem(e) if e.is_int());
                if !ok {
                    let msg = format!(
                        "array index must be an integer, found {}",
                        self.ty_name(&v.ty)
                    );
                    self.diag(codes::IMPLICIT_CONVERSION, msg, v.span, None);
                }
                idx.push(v);
            }
        }
        match self.strip(&base.ty) {
            Ty::Array { dims, elem } => {
                for (k, v) in idx.iter().enumerate() {
                    if let (Some(Some((lo, hi))), Some(K::Int(x))) = (dims.get(k), v.k) {
                        if x < *lo || x > *hi {
                            let msg = format!("index {x} is outside the bounds {lo}..{hi}");
                            self.diag(codes::CONSTANT_INDEX_OUT_OF_BOUNDS, msg, v.span, None);
                        }
                    }
                }
                let e = ExprKind::Index(Box::new(base.ir()), idx.into_iter().map(V::ir).collect());
                V::with(*elem, span, e)
            }
            _ => V::unknown(span),
        }
    }

    // ---------------------------------------------------------------- calls

    fn args(&self, list: &'a Node) -> Vec<Arg<'a>> {
        let mut out = Vec::new();
        for a in self.child_nodes(list, N::Arg) {
            let its = self.items(a);
            let name = match (its.first().copied(), its.get(1).copied()) {
                (Some(Item::Tok(n)), Some(Item::Tok(op))) if self.tkind(n) == T::Ident => {
                    match self.tkind(op) {
                        T::Assign => Some((n, false)),
                        T::Arrow => Some((n, true)),
                        _ => None,
                    }
                }
                _ => None,
            };
            if let Some(e) = self.first_node(a) {
                out.push(Arg { name, expr: e });
            }
        }
        out
    }

    fn call(&mut self, callee: &'a Node, list: &'a Node, span: Span) -> V {
        let args = self.args(list);
        if callee.kind != N::NameRef {
            let b = self.expr(callee);
            return self.bind_call(b, &args, span);
        }
        let Some(Item::Tok(i)) = self.items(callee).first().copied() else {
            return V::unknown(span);
        };
        let name = self.text(i);
        let cspan = self.tok_span(i);
        if let Some((t, slot)) = self.lookup_var(name) {
            return self.bind_call(V::with(t, cspan, ExprKind::Var(slot)), &args, span);
        }
        if let Some(&id) = self.types.get(&name.to_ascii_lowercase()) {
            if matches!(&self.defs[id].kind, Kind::Pou(p) if p.kind == PouKind::Function) {
                return self.bind_call(V::of(Ty::Named(id), cspan), &args, span);
            }
        }
        let up = name.to_ascii_uppercase();
        if let Some(b) = builtin(&up) {
            return self.builtin_call(&up, b, &args, span);
        }
        self.diag(
            codes::UNKNOWN_NAME,
            format!("unknown function '{name}'"),
            cspan,
            None,
        );
        for a in &args {
            self.expr(a.expr);
        }
        V::unknown(span)
    }

    /// Call of a function-block or program instance (`callee` is a place),
    /// or of a user function (`callee` has the function's type, no place).
    fn bind_call(&mut self, callee: V, args: &[Arg<'a>], span: Span) -> V {
        let pou = match self.strip(&callee.ty) {
            Ty::Named(id) => match &self.defs[id].kind {
                Kind::Pou(p) => Some((id, self.defs[id].name.clone(), p.clone())),
                _ => None,
            },
            _ => None,
        };
        let Some((id, pname, p)) = pou else {
            for a in args {
                self.expr(a.expr);
            }
            return V::unknown(span);
        };
        let input_slots: Vec<usize> = (0..p.vars.len())
            .filter(|&i| matches!(p.vars[i].section, Section::Input | Section::InOut))
            .collect();
        let (mut inputs, mut outputs) = (Vec::new(), Vec::new());
        for (pos, a) in args.iter().enumerate() {
            match a.name {
                Some((t, out)) => {
                    let n = self.text(t);
                    let slot = (0..p.vars.len()).find(|&i| {
                        let v = &p.vars[i];
                        v.name.eq_ignore_ascii_case(n)
                            && if out {
                                v.section == Section::Output
                            } else {
                                matches!(v.section, Section::Input | Section::InOut)
                            }
                    });
                    match slot {
                        Some(s) if out => {
                            let target = self.expr(a.expr);
                            if !self.compatible(&target.ty, &p.vars[s].ty) {
                                let src = V::of(p.vars[s].ty.clone(), target.span);
                                self.mismatch(&target.ty, &src);
                            }
                            outputs.push((s, target.ir()));
                        }
                        Some(s) => {
                            let val = self.expr(a.expr);
                            self.coerce(&p.vars[s].ty, &val);
                            inputs.push((s, val.ir()));
                        }
                        None => {
                            let what = if out { "output" } else { "input" };
                            let sp = self.tok_span(t);
                            self.diag(
                                codes::UNKNOWN_NAME,
                                format!("'{pname}' has no {what} '{n}'"),
                                sp,
                                None,
                            );
                            self.expr(a.expr);
                        }
                    }
                }
                None => {
                    let val = self.expr(a.expr);
                    if let Some(&s) = input_slots.get(pos) {
                        self.coerce(&p.vars[s].ty, &val);
                        inputs.push((s, val.ir()));
                    }
                }
            }
        }
        let (target, ty) = if p.kind == PouKind::Function {
            (
                CallTarget::Function(id),
                p.ret.clone().unwrap_or(Ty::Unknown),
            )
        } else {
            (CallTarget::Instance(callee.ir(), id), Ty::Unknown)
        };
        let call = ir::Call {
            target,
            inputs,
            outputs,
            args: Vec::new(),
        };
        V::with(ty, span, ExprKind::Call(Box::new(call)))
    }

    /// [stdlib.conversions], [stdlib.functions], [tests.assert].
    fn builtin_call(&mut self, up: &str, b: Builtin, args: &[Arg<'a>], span: Span) -> V {
        let vals: Vec<V> = args.iter().map(|a| self.expr(a.expr)).collect();
        let bool_ty = Ty::Elem(Elem::Bool);
        let (ret, hint): (Ty, Option<Ty>) = match b {
            Builtin::Advance => {
                // [tests.time]: mocked time exists only in TEST blocks.
                if self.scope_kind() != Some(PouKind::Test) {
                    let msg = "ADVANCE is only available in TEST blocks".to_string();
                    self.diag(codes::UNKNOWN_NAME, msg, span, None);
                }
                let t = match vals.first() {
                    Some(v) => {
                        let st = self.strip(&v.ty);
                        if matches!(st, Ty::Elem(e) if e.is_duration()) || st == Ty::Unknown {
                            st
                        } else {
                            self.mismatch(&Ty::Elem(Elem::Time), v);
                            Ty::Unknown
                        }
                    }
                    None => Ty::Unknown,
                };
                (Ty::Unknown, Some(t))
            }
            Builtin::AssertBool => {
                if let Some(v) = vals.first() {
                    self.coerce(&bool_ty, v);
                }
                (Ty::Unknown, None)
            }
            Builtin::AssertCmp => {
                let t = match vals.as_slice() {
                    [a, c, ..] => self.unify(a, c, up),
                    _ => Ty::Unknown,
                };
                (Ty::Unknown, Some(t))
            }
            Builtin::Conv(from, to) => {
                if let Some(v) = vals.first() {
                    self.coerce(&from, v);
                }
                (to, Some(from))
            }
            Builtin::ToConv(to) => (to, None),
            Builtin::Trunc => {
                if let Some(v) = vals.first() {
                    let st = self.strip(&v.ty);
                    let ok = matches!(st, Ty::RealLit | Ty::IntLit | Ty::Unknown)
                        || matches!(st, Ty::Elem(e) if e.is_real());
                    if !ok {
                        let msg = format!(
                            "TRUNC needs a REAL or LREAL argument, found {}",
                            self.ty_name(&v.ty)
                        );
                        self.diag(codes::IMPLICIT_CONVERSION, msg, v.span, None);
                    }
                }
                (Ty::Elem(Elem::Dint), None)
            }
            Builtin::SameAsArg => {
                let t = vals.first().map_or(Ty::Unknown, |v| self.strip(&v.ty));
                let t = if t == Ty::IntLit && !matches!(up, "SHL" | "SHR" | "ROL" | "ROR" | "ABS") {
                    Ty::Elem(Elem::Lreal)
                } else if t == Ty::IntLit {
                    Ty::Elem(Elem::Dint)
                } else if t == Ty::RealLit {
                    Ty::Elem(Elem::Lreal)
                } else {
                    t
                };
                (t.clone(), Some(t))
            }
            Builtin::Common | Builtin::Sel | Builtin::Mux => {
                let skip = usize::from(!matches!(b, Builtin::Common));
                if matches!(b, Builtin::Sel) {
                    if let Some(g) = vals.first() {
                        self.coerce(&bool_ty, g);
                    }
                }
                let mut it = vals.iter().skip(skip);
                let Some(first) = it.next() else {
                    return V::unknown(span);
                };
                let mut acc = first.clone();
                for v in it {
                    let t = self.unify(&acc, v, up);
                    if t == Ty::Unknown {
                        return V::unknown(span);
                    }
                    acc = V::of(t, v.span);
                }
                let t = match acc.ty {
                    Ty::IntLit => Ty::Elem(Elem::Dint),
                    Ty::RealLit => Ty::Elem(Elem::Lreal),
                    t => t,
                };
                (t.clone(), Some(t))
            }
            Builtin::StrInt => (Ty::Elem(Elem::Int), None),
            Builtin::StrFn => {
                let wide = matches!(
                    vals.first().map(|v| self.strip(&v.ty)),
                    Some(Ty::Str { wide: true, .. })
                );
                (
                    Ty::Str {
                        wide,
                        len: DEFAULT_STRING_LEN,
                    },
                    None,
                )
            }
        };
        let call = ir::Call {
            target: CallTarget::Builtin {
                name: up.to_string(),
                ty: hint,
            },
            inputs: Vec::new(),
            outputs: Vec::new(),
            args: vals.into_iter().map(V::ir).collect(),
        };
        V::with(ret, span, ExprKind::Call(Box::new(call)))
    }
}

fn cmp(opk: T, o: std::cmp::Ordering) -> bool {
    use std::cmp::Ordering::*;
    match opk {
        T::Eq => o == Equal,
        T::Neq => o != Equal,
        T::Lt => o == Less,
        T::Gt => o == Greater,
        T::Le => o != Greater,
        _ => o != Less,
    }
}

/// Constant folding. `None`: not folded (no error).
fn fold(cls: Cls, opk: T, opt: &str, a: K, b: K) -> Option<Fold> {
    let ok = |r: Option<i128>| Some(r.map_or(Fold::Overflow, |v| Fold::Ok(K::Int(v))));
    match (a, b) {
        (K::Int(x), K::Int(y)) => match cls {
            Cls::Cmp => Some(Fold::Ok(K::Bool(cmp(opk, x.cmp(&y))))),
            Cls::Arith => ok(match opk {
                T::Plus => x.checked_add(y),
                T::Minus => x.checked_sub(y),
                T::Star => x.checked_mul(y),
                _ => x.checked_div(y),
            }),
            Cls::Mod => ok(x.checked_rem(y)),
            Cls::Pow => {
                if y < 0 {
                    None
                } else {
                    ok(u32::try_from(y).ok().and_then(|e| x.checked_pow(e)))
                }
            }
            Cls::Logic => Some(Fold::Ok(K::Int(match opt {
                "AND" | "AND_THEN" | "&" => x & y,
                "OR" | "OR_ELSE" => x | y,
                _ => x ^ y,
            }))),
        },
        (K::Bool(x), K::Bool(y)) => match cls {
            Cls::Logic => Some(Fold::Ok(K::Bool(match opt {
                "AND" | "AND_THEN" | "&" => x && y,
                "OR" | "OR_ELSE" => x || y,
                _ => x ^ y,
            }))),
            Cls::Cmp => Some(Fold::Ok(K::Bool(cmp(opk, x.cmp(&y))))),
            _ => None,
        },
        (K::Int(_) | K::Real(_), K::Int(_) | K::Real(_)) => {
            let f = |k| match k {
                K::Int(v) => v as f64,
                K::Real(v) => v,
                _ => 0.0,
            };
            let (x, y) = (f(a), f(b));
            match cls {
                Cls::Cmp => x.partial_cmp(&y).map(|o| Fold::Ok(K::Bool(cmp(opk, o)))),
                Cls::Arith => Some(Fold::Ok(K::Real(match opk {
                    T::Plus => x + y,
                    T::Minus => x - y,
                    T::Star => x * y,
                    _ => x / y,
                }))),
                Cls::Pow => Some(Fold::Ok(K::Real(x.powf(y)))),
                _ => None,
            }
        }
        _ => None,
    }
}
