//! The checker: name resolution and type checking over the syntax tree.
//!
//! Passes: (1) register every type and POU name, (2) resolve types and POU
//! interfaces, (3) find structures that contain themselves, (4) check initial
//! values and statements. Expressions are typed bottom-up; untyped literals
//! take their type from the other operand or the assignment target
//! ([types.literal.untyped]). `Ty::Unknown` absorbs follow-on errors.

use std::collections::{HashMap, HashSet};

use rootplc_diag::{Code, Diagnostic, Span, codes};
use rootplc_syntax::{Element, Node, NodeKind as N, Token, TokenKind as T};

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

#[derive(Clone, Copy, PartialEq, Eq)]
enum PouKind {
    Program,
    Function,
    FunctionBlock,
    Test,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Section {
    Input,
    Output,
    InOut,
    Local,
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

/// A compile-time constant.
#[derive(Clone, Copy, PartialEq, Debug)]
enum K {
    Int(i128),
    Real(f64),
    Bool(bool),
    Str(usize),
}

/// A typed expression.
#[derive(Clone, Debug)]
struct V {
    ty: Ty,
    k: Option<K>,
    /// A literal, possibly negated: out of range is RP0102, not RP0101.
    leaf: bool,
    span: Span,
}

impl V {
    fn of(ty: Ty, span: Span) -> V {
        V {
            ty,
            k: None,
            leaf: false,
            span,
        }
    }
    fn unknown(span: Span) -> V {
        V::of(Ty::Unknown, span)
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

pub(crate) struct Checker<'a> {
    /// Source text and tokens of every file in the project.
    files: Vec<(&'a str, &'a [Token])>,
    /// File whose tokens are being read.
    cur: usize,
    defs: Vec<Def<'a>>,
    types: HashMap<String, usize>,
    scope: Option<usize>,
    /// Diagnostics with the index of their file.
    pub(crate) diags: Vec<(usize, Diagnostic)>,
}

fn is_trivia(k: T) -> bool {
    k.is_trivia() || k == T::Pragma
}

/// Parse an integer literal body: `1_000`, `16#FF`, `-3`.
fn parse_int(text: &str) -> Option<i128> {
    let t: String = text.chars().filter(|c| *c != '_').collect();
    let (neg, t) = match t.strip_prefix('-') {
        Some(r) => (true, r),
        None => (false, t.strip_prefix('+').unwrap_or(&t)),
    };
    let v = match t.split_once('#') {
        Some((b, d)) => i128::from_str_radix(d, b.parse::<u32>().ok()?).ok()?,
        None => t.parse::<i128>().ok()?,
    };
    Some(if neg { -v } else { v })
}

/// Number of characters in a quoted string literal, after `$` escapes.
fn str_len(quoted: &str, wide: bool) -> usize {
    let inner = quoted.get(1..quoted.len().saturating_sub(1)).unwrap_or("");
    let mut n = 0;
    let mut it = inner.chars().peekable();
    while let Some(c) = it.next() {
        if c == '$' {
            if it.peek().is_some_and(char::is_ascii_hexdigit) {
                for _ in 0..(if wide { 4 } else { 2 }) {
                    it.next();
                }
            } else {
                it.next();
            }
        }
        n += 1;
    }
    n
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
        self.types.insert(name.to_ascii_lowercase(), id);
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
                            if let Some(Item::Node(e)) = its.get(k + 1).copied() {
                                if let Ty::Str { wide, .. } = ty {
                                    match self.const_int(e) {
                                        Some(v) if (1..=65_535).contains(&v) => {
                                            ty = Ty::Str {
                                                wide,
                                                len: v as u32,
                                            };
                                        }
                                        Some(v) => {
                                            let sp = self.span(e);
                                            self.diag(
                                                codes::INVALID_BOUNDS,
                                                format!("string length {v} is outside 1..65535"),
                                                sp,
                                                None,
                                            );
                                        }
                                        None => {}
                                    }
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
                                        self.diag(
                                            codes::INVALID_BOUNDS,
                                            format!("subrange {a}..{b}: the lower bound exceeds the upper bound"),
                                            sp,
                                            None,
                                        );
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
            let its = self.items(v);
            let Some(Item::Tok(t)) = its.first().copied() else {
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
                                self.diag(
                                    codes::INVALID_BOUNDS,
                                    format!("array bounds {a}..{b}: the lower bound exceeds the upper bound"),
                                    sp,
                                    None,
                                );
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
                    T::Integer => parse_int(self.text(i)),
                    T::TypedLiteral => parse_int(self.text(i).split_once('#')?.1),
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
        match &d.kind {
            Kind::Alias(t) => {
                if let Some(i) = d.init {
                    self.scope = None;
                    self.initializer(t, i);
                }
            }
            Kind::Struct(members) => {
                self.scope = None;
                for v in members {
                    if let Some(i) = v.init {
                        self.initializer(&v.ty, i);
                    }
                }
            }
            Kind::Pou(p) => {
                let Some(node) = d.node else { return };
                self.scope = Some(id);
                let mut seen = HashSet::new();
                for v in &p.vars {
                    if !seen.insert(v.name.to_ascii_lowercase()) {
                        self.diag(
                            codes::DUPLICATE_NAME,
                            format!("'{}' is already declared in {}", v.name, d.name),
                            v.span,
                            None,
                        );
                    }
                }
                for v in &p.vars {
                    if let Some(i) = v.init {
                        self.initializer(&v.ty, i);
                    }
                }
                for s in self.child_nodes(node, N::StmtList) {
                    self.stmt_list(s);
                }
                self.scope = None;
            }
            _ => {}
        }
    }

    /// [variables.initializer.check].
    fn initializer(&mut self, ty: &Ty, n: &'a Node) {
        let Some(inner) = self.first_node(n) else {
            return;
        };
        let span = self.span(inner);
        match inner.kind {
            N::ArrayInit => {
                let elem = match self.strip(ty) {
                    Ty::Array { elem, .. } => *elem,
                    Ty::Unknown => return,
                    _ => {
                        let msg =
                            format!("array initializer for a value of type {}", self.ty_name(ty));
                        self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                        return;
                    }
                };
                for c in self.child_nodes(inner, N::Initializer) {
                    self.initializer(&elem, c);
                }
            }
            N::StructInit => {
                let members = match ty {
                    Ty::Named(i) => match &self.defs[*i].kind {
                        Kind::Struct(m) => m.clone(),
                        _ => Vec::new(),
                    },
                    Ty::Unknown => return,
                    _ => Vec::new(),
                };
                if members.is_empty() {
                    let msg = format!(
                        "structure initializer for a value of type {}",
                        self.ty_name(ty)
                    );
                    self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                    return;
                }
                let mut cur = None;
                for it in self.items(inner) {
                    match it {
                        Item::Tok(t) if self.tkind(t) == T::Ident => cur = Some(t),
                        Item::Node(c) if c.kind == N::Initializer => {
                            let Some(t) = cur.take() else { continue };
                            let name = self.text(t);
                            match members.iter().find(|m| m.name.eq_ignore_ascii_case(name)) {
                                Some(m) => self.initializer(&m.ty, c),
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
            }
            _ => {
                let v = self.expr(inner);
                self.coerce(ty, &v);
            }
        }
    }

    fn stmt_list(&mut self, n: &'a Node) {
        for it in self.items(n) {
            if let Item::Node(s) = it {
                self.stmt(s);
            }
        }
    }

    fn stmt(&mut self, n: &'a Node) {
        let its = self.items(n);
        match n.kind {
            N::AssignStmt => {
                if let (Some(Item::Node(t)), Some(Item::Tok(op)), Some(Item::Node(e))) = (
                    its.first().copied(),
                    its.get(1).copied(),
                    its.get(2).copied(),
                ) {
                    let target = self.expr(t);
                    let value = self.expr(e);
                    if self.tkind(op) == T::Assign {
                        self.coerce(&target.ty, &value);
                    }
                }
            }
            N::CallStmt => {
                if let Some(c) = self.first_node(n) {
                    self.expr(c);
                }
            }
            N::IfStmt => {
                let mut want_cond = false;
                for it in its {
                    match it {
                        Item::Tok(t) if self.is_kw(t, "IF") || self.is_kw(t, "ELSIF") => {
                            want_cond = true
                        }
                        Item::Node(c) if c.kind == N::StmtList => self.stmt_list(c),
                        Item::Node(c) if want_cond => {
                            self.condition(c);
                            want_cond = false;
                        }
                        _ => {}
                    }
                }
            }
            N::CaseStmt => {
                let mut sel: Option<V> = None;
                for it in its {
                    let Item::Node(c) = it else { continue };
                    match c.kind {
                        N::CaseElement => {
                            for x in self.items(c) {
                                let Item::Node(e) = x else { continue };
                                if e.kind == N::StmtList {
                                    self.stmt_list(e);
                                } else {
                                    let v = self.expr(e);
                                    if let Some(s) = &sel {
                                        let st = s.ty.clone();
                                        self.coerce(&st, &v);
                                    }
                                }
                            }
                        }
                        N::StmtList => self.stmt_list(c),
                        _ if sel.is_none() => sel = Some(self.expr(c)),
                        _ => {}
                    }
                }
            }
            N::ForStmt => {
                let mut ctrl = Ty::Unknown;
                if let Some(Item::Tok(t)) = its.get(1).copied() {
                    let name = self.text(t);
                    let span = self.tok_span(t);
                    match self.lookup_var(name) {
                        Some(ty) => {
                            let ok = match self.strip(&ty) {
                                Ty::Elem(e) => e.is_int(),
                                Ty::Unknown => true,
                                _ => false,
                            };
                            if ok {
                                ctrl = ty;
                            } else {
                                let msg = format!(
                                    "FOR control variable '{name}' must be an integer, not {}",
                                    self.ty_name(&ty)
                                );
                                self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                            }
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
                for it in its {
                    let Item::Node(c) = it else { continue };
                    if c.kind == N::StmtList {
                        self.stmt_list(c);
                    } else {
                        let v = self.expr(c);
                        self.coerce(&ctrl, &v);
                    }
                }
            }
            N::WhileStmt | N::RepeatStmt => {
                for it in its {
                    let Item::Node(c) = it else { continue };
                    if c.kind == N::StmtList {
                        self.stmt_list(c);
                    } else {
                        self.condition(c);
                    }
                }
            }
            _ => {}
        }
    }

    /// Conditions are `BOOL`, with no implicit conversion, [statements.if].
    fn condition(&mut self, c: &'a Node) {
        let v = self.expr(c);
        self.coerce(&Ty::Elem(Elem::Bool), &v);
    }

    // ---------------------------------------------------------------- names

    fn lookup_var(&self, name: &str) -> Option<Ty> {
        let id = self.scope?;
        let Kind::Pou(p) = &self.defs[id].kind else {
            return None;
        };
        if let Some(v) = p.vars.iter().find(|v| v.name.eq_ignore_ascii_case(name)) {
            return Some(v.ty.clone());
        }
        if p.kind == PouKind::Function && self.defs[id].name.eq_ignore_ascii_case(name) {
            return p.ret.clone();
        }
        None
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
            }),
            many => {
                let names: Vec<String> = many
                    .iter()
                    .map(|(id, _)| self.defs[*id].name.clone())
                    .collect();
                let hint = format!("write {}#{name}", names[0]);
                self.diag(
                    codes::AMBIGUOUS_ENUM_VALUE,
                    format!(
                        "'{name}' is a value of several enumerations ({})",
                        names.join(", ")
                    ),
                    span,
                    Some(hint),
                );
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
                return if matches!(tb, Ty::Elem(e) if e.is_real()) {
                    true
                } else {
                    self.mismatch(to, v);
                    false
                };
            }
            Ty::Null => {
                return if matches!(tb, Ty::Ref(_)) {
                    true
                } else {
                    self.mismatch(to, v);
                    false
                };
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
                self.diag(
                    codes::IMPLICIT_CONVERSION,
                    msg,
                    span,
                    Some("convert one operand explicitly, for example with TO_INT(...)".into()),
                );
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
                    if let Some(t) = self.lookup_var(name) {
                        return V::of(t, span);
                    }
                    if let Some(v) = self.enum_value(name, span) {
                        return v;
                    }
                    self.diag(
                        codes::UNKNOWN_NAME,
                        format!("unknown name '{name}'"),
                        span,
                        Some("declare it in a VAR section of this POU".into()),
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
                Some(b) => match self.expr(b).ty {
                    Ty::Ref(t) => V::of(*t, span),
                    _ => V::unknown(span),
                },
                None => V::unknown(span),
            },
            N::RefExpr => match self.first_node(n) {
                Some(x) => {
                    let v = self.expr(x);
                    V::of(Ty::Ref(Box::new(v.ty)), span)
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
        let lit = |ty, k| V {
            ty,
            k,
            leaf: true,
            span,
        };
        let el = |e| V {
            ty: Ty::Elem(e),
            k: None,
            leaf: true,
            span,
        };
        match self.tkind(i) {
            T::Integer => match parse_int(text) {
                Some(v) => lit(Ty::IntLit, Some(K::Int(v))),
                None => V::unknown(span),
            },
            T::Real => lit(
                Ty::RealLit,
                text.replace('_', "").parse::<f64>().ok().map(K::Real),
            ),
            T::TypedLiteral => self.typed_literal(text, span),
            T::Duration => el(if up.starts_with("LT") {
                Elem::Ltime
            } else {
                Elem::Time
            }),
            T::Date => el(if up.starts_with("LD") {
                Elem::Ldate
            } else {
                Elem::Date
            }),
            T::TimeOfDay => el(if up.starts_with("LT") {
                Elem::Ltod
            } else {
                Elem::Tod
            }),
            T::DateAndTime => el(if up.starts_with("LD") {
                Elem::Ldt
            } else {
                Elem::Dt
            }),
            T::Char => el(if up.starts_with('W') {
                Elem::Wchar
            } else {
                Elem::Char
            }),
            T::String => {
                let n = str_len(text, false);
                lit(
                    Ty::Str {
                        wide: false,
                        len: n as u32,
                    },
                    Some(K::Str(n)),
                )
            }
            T::WString => {
                let n = str_len(text, true);
                lit(
                    Ty::Str {
                        wide: true,
                        len: n as u32,
                    },
                    Some(K::Str(n)),
                )
            }
            T::EnumLiteral => self.enum_literal(text, span),
            T::DirectVariable => {
                let mut cs = text.trim_start_matches('%').chars().skip(1);
                match cs.next().map(|c| c.to_ascii_uppercase()) {
                    Some('X') => el(Elem::Bool),
                    Some('B') => el(Elem::Byte),
                    Some('W') => el(Elem::Word),
                    Some('D') => el(Elem::Dword),
                    Some('L') => el(Elem::Lword),
                    Some(c) if c.is_ascii_digit() => el(Elem::Bool),
                    _ => V::unknown(span),
                }
            }
            T::Keyword => match up.as_str() {
                "TRUE" => lit(Ty::Elem(Elem::Bool), Some(K::Bool(true))),
                "FALSE" => lit(Ty::Elem(Elem::Bool), Some(K::Bool(false))),
                "NULL" => lit(Ty::Null, None),
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
            let n = str_len(rest, wide);
            return V {
                ty: Ty::Str {
                    wide,
                    len: n as u32,
                },
                k: Some(K::Str(n)),
                leaf: true,
                span,
            };
        }
        let Some(e) = Elem::from_name(&up) else {
            return V::unknown(span);
        };
        let ty = Ty::Elem(e);
        if e == Elem::Bool {
            let k = match rest.to_ascii_uppercase().as_str() {
                "1" | "TRUE" => Some(K::Bool(true)),
                "0" | "FALSE" => Some(K::Bool(false)),
                _ => None,
            };
            return V {
                ty,
                k,
                leaf: true,
                span,
            };
        }
        if let Some((lo, hi)) = e.int_range() {
            if let Some(v) = parse_int(rest) {
                if v < lo || v > hi {
                    let msg = format!("literal {v} does not fit {} ({lo}..{hi})", e.name());
                    self.diag(codes::LITERAL_OUT_OF_RANGE, msg, span, None);
                    return V::of(ty, span);
                }
                return V {
                    ty,
                    k: Some(K::Int(v)),
                    leaf: true,
                    span,
                };
            }
        }
        if e.is_real() {
            let k = rest.replace('_', "").parse::<f64>().ok().map(K::Real);
            return V {
                ty,
                k,
                leaf: true,
                span,
            };
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
            return V {
                ty: v.ty,
                k,
                leaf: false,
                span,
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
        let k = if optext == "-" {
            match v.k {
                Some(K::Int(x)) => Some(K::Int(-x)),
                Some(K::Real(x)) => Some(K::Real(-x)),
                _ => None,
            }
        } else {
            v.k
        };
        V {
            ty: st,
            k,
            leaf: v.leaf,
            span,
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
        let cls = match opk {
            T::Plus | T::Minus | T::Star | T::Slash => Cls::Arith,
            T::Power => Cls::Pow,
            T::Eq | T::Neq | T::Lt | T::Gt | T::Le | T::Ge => Cls::Cmp,
            T::Ampersand => Cls::Logic,
            _ if opt == "MOD" => Cls::Mod,
            _ => Cls::Logic,
        };
        // [types.int.division]: constant divisor zero.
        if (opk == T::Slash || cls == Cls::Mod) && r.k == Some(K::Int(0)) {
            self.diag(
                codes::CONSTANT_OVERFLOW,
                "division by zero in a constant expression".into(),
                r.span,
                Some("the divisor is the constant 0".into()),
            );
            return V::of(self.strip(&l.ty), span);
        }
        // Duration scaled by an integer.
        if matches!(opk, T::Star | T::Slash) {
            let (lt, rt) = (self.strip(&l.ty), self.strip(&r.ty));
            if matches!(lt, Ty::Elem(e) if e.is_duration())
                && (matches!(rt, Ty::IntLit) || matches!(rt, Ty::Elem(e) if e.is_int()))
            {
                return V::of(lt, span);
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
            st
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
        V {
            ty: rty,
            k,
            leaf: false,
            span,
        }
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
            return match bt {
                Ty::Elem(e) if e.is_bit() || e.is_int() => V::of(Ty::Elem(Elem::Bool), span),
                _ => V::unknown(span),
            };
        }
        let name = self.text(m);
        let Ty::Named(id) = bt else {
            return V::unknown(span);
        };
        let tname = self.defs[id].name.clone();
        let found = match &self.defs[id].kind {
            Kind::Struct(ms) => Some(
                ms.iter()
                    .find(|v| v.name.eq_ignore_ascii_case(name))
                    .map(|v| v.ty.clone()),
            ),
            Kind::Pou(p) => Some(
                p.vars
                    .iter()
                    .find(|v| v.section != Section::Local && v.name.eq_ignore_ascii_case(name))
                    .map(|v| v.ty.clone()),
            ),
            _ => None,
        };
        match found {
            Some(Some(t)) => V::of(t, span),
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
                            self.diag(
                                codes::CONSTANT_INDEX_OUT_OF_BOUNDS,
                                format!("index {x} is outside the bounds {lo}..{hi}"),
                                v.span,
                                None,
                            );
                        }
                    }
                }
                V::of(*elem, span)
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
            return self.bind_call(&b.ty, &args, span);
        }
        let Some(Item::Tok(i)) = self.items(callee).first().copied() else {
            return V::unknown(span);
        };
        let name = self.text(i);
        if let Some(t) = self.lookup_var(name) {
            return self.bind_call(&t, &args, span);
        }
        if let Some(&id) = self.types.get(&name.to_ascii_lowercase()) {
            if matches!(&self.defs[id].kind, Kind::Pou(p) if p.kind == PouKind::Function) {
                return self.bind_call(&Ty::Named(id), &args, span);
            }
        }
        let up = name.to_ascii_uppercase();
        if let Some(b) = builtin(&up) {
            return self.builtin_call(&up, b, &args, span);
        }
        let sp = self.tok_span(i);
        self.diag(
            codes::UNKNOWN_NAME,
            format!("unknown function '{name}'"),
            sp,
            None,
        );
        for a in &args {
            self.expr(a.expr);
        }
        V::unknown(span)
    }

    /// Call of a function-block or program instance, or of a user function.
    fn bind_call(&mut self, ty: &Ty, args: &[Arg<'a>], span: Span) -> V {
        let pou = match self.strip(ty) {
            Ty::Named(id) => match &self.defs[id].kind {
                Kind::Pou(p) => Some((self.defs[id].name.clone(), p.clone())),
                _ => None,
            },
            _ => None,
        };
        let Some((pname, p)) = pou else {
            for a in args {
                self.expr(a.expr);
            }
            return V::unknown(span);
        };
        let inputs: Vec<&Var<'a>> = p
            .vars
            .iter()
            .filter(|v| matches!(v.section, Section::Input | Section::InOut))
            .collect();
        for (pos, a) in args.iter().enumerate() {
            match a.name {
                Some((t, out)) => {
                    let n = self.text(t);
                    let want = |v: &&Var<'a>| {
                        v.name.eq_ignore_ascii_case(n)
                            && if out {
                                v.section == Section::Output
                            } else {
                                matches!(v.section, Section::Input | Section::InOut)
                            }
                    };
                    match p.vars.iter().find(want) {
                        Some(v) if out => {
                            let target = self.expr(a.expr);
                            if !self.compatible(&target.ty, &v.ty) {
                                let src = V::of(v.ty.clone(), target.span);
                                self.mismatch(&target.ty, &src);
                            }
                        }
                        Some(v) => {
                            let val = self.expr(a.expr);
                            self.coerce(&v.ty, &val);
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
                    if let Some(v) = inputs.get(pos) {
                        self.coerce(&v.ty, &val);
                    }
                }
            }
        }
        match p.ret {
            Some(t) if p.kind == PouKind::Function => V::of(t, span),
            _ => V::unknown(span),
        }
    }

    /// [stdlib.conversions], [stdlib.functions], [tests.assert].
    fn builtin_call(&mut self, up: &str, b: Builtin, args: &[Arg<'a>], span: Span) -> V {
        let vals: Vec<V> = args.iter().map(|a| self.expr(a.expr)).collect();
        let bool_ty = Ty::Elem(Elem::Bool);
        match b {
            Builtin::AssertBool => {
                if let Some(v) = vals.first() {
                    self.coerce(&bool_ty, v);
                }
                V::unknown(span)
            }
            Builtin::AssertCmp => {
                if let [a, c, ..] = vals.as_slice() {
                    self.unify(a, c, up);
                }
                V::unknown(span)
            }
            Builtin::Conv(from, to) => {
                if let Some(v) = vals.first() {
                    self.coerce(&from, v);
                }
                V::of(to, span)
            }
            Builtin::ToConv(to) => V::of(to, span),
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
                V::of(Ty::Elem(Elem::Dint), span)
            }
            Builtin::SameAsArg => match vals.first() {
                Some(v) => V::of(self.strip(&v.ty), span),
                None => V::unknown(span),
            },
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
                    acc = V {
                        ty: t,
                        k: None,
                        leaf: false,
                        span: v.span,
                    };
                }
                V::of(acc.ty, span)
            }
            Builtin::StrInt => V::of(Ty::Elem(Elem::Int), span),
            Builtin::StrFn => {
                let wide = matches!(
                    vals.first().map(|v| self.strip(&v.ty)),
                    Some(Ty::Str { wide: true, .. })
                );
                V::of(
                    Ty::Str {
                        wide,
                        len: DEFAULT_STRING_LEN,
                    },
                    span,
                )
            }
        }
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

#[cfg(test)]
mod tests {
    use super::{parse_int, str_len};

    #[test]
    fn literals() {
        assert_eq!(parse_int("1_000"), Some(1000));
        assert_eq!(parse_int("16#FF"), Some(255));
        assert_eq!(parse_int("-3"), Some(-3));
        assert_eq!(parse_int("2#1010_0101"), Some(165));
        assert_eq!(str_len("'it$'s $$5$N'", false), 8);
        assert_eq!(str_len("'$41'", false), 1);
        assert_eq!(str_len("\"温度\"", true), 2);
    }
}
