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
    /// Declared REFERENCE TO: uses go to the target, [types.reference.alias].
    alias: bool,
    /// Declared in VAR_IN_OUT CONSTANT: the argument may be a value.
    read_only: bool,
}

#[derive(Clone)]
struct Pou<'a> {
    kind: PouKind,
    vars: Vec<Var<'a>>,
    ret: Option<Ty>,
    /// The function block this one extends; its variables come first.
    base: Option<usize>,
    /// Number of leading variables inherited from `base`.
    inherited: usize,
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
    /// LOWER_BOUND / UPPER_BOUND, [stdlib.functions.bounds].
    Bound,
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

/// A global variable: where it is declared and, for a CONSTANT, its value.
#[derive(Clone)]
struct GlobalVar {
    file: usize,
    name: String,
    value: Option<i128>,
    /// Namespace it was declared in (lower case), e.g. a TwinCAT GVL name.
    ns: Option<String>,
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
    /// `VAR_GLOBAL` sections outside POUs: (file, section, CONSTANT?), [config.global-list].
    global_sections: Vec<(usize, &'a Node, bool, Option<String>)>,
    /// Namespace being collected (lower case), [pous.namespace].
    cur_ns: Option<String>,
    /// Qualifier of the name being resolved (`GVL_A` in `GVL_A.x`).
    qualifier: Option<String>,
    /// Global variables in slot order; their types live in `defs[globals_def]`.
    globals: Vec<GlobalVar>,
    /// The synthetic definition holding every global variable.
    globals_def: Option<usize>,
    /// CONFIGURATION blocks: (file, node), [config.configuration].
    configs: Vec<(usize, &'a Node)>,
    /// Method definition -> the function block or program it belongs to.
    owner: HashMap<usize, usize>,
    /// Interface -> the interfaces it extends, [pous.oop.interface].
    itf_bases: HashMap<usize, Vec<usize>>,
    /// Function block -> the interfaces it names in IMPLEMENTS.
    implements: HashMap<usize, Vec<usize>>,
    /// Function blocks declared ABSTRACT.
    abstract_fbs: HashSet<usize>,
    /// Structure -> (base structure, number of inherited members).
    struct_base: HashMap<usize, (usize, usize)>,
    /// While set, a REFERENCE TO variable denotes the reference itself.
    raw_alias: bool,
    /// The last function block or program collected in the current file.
    last_block: Option<(usize, String)>,
    /// Declared-only library functions (lower case), [stdlib.compat].
    declare_only: HashSet<String>,
    /// Names that qualify a declaration in expressions: active libraries and
    /// declared namespaces (lower case).
    qualifiers: HashSet<String>,
    /// Operators enabled by active libraries (upper case), e.g. SIZEOF.
    intrinsics: HashSet<String>,
    /// Base type of enumerations declared with one (`INT (a, b)`).
    enum_base: HashMap<usize, Elem>,
    /// Enumerations declared with {attribute 'strict'}.
    strict_enums: HashSet<usize>,
    /// Span of the place an assignment writes, while it is checked
    /// ([pous.call.local-read]: internal variables are read-only from outside).
    write_target: Option<Span>,
    /// The enumeration an expression is expected to have ([types.derived.enum]:
    /// an unqualified value of several enumerations resolves to it).
    enum_hint: Option<usize>,
    /// Property accessor definition -> (its PROPERTY node, is the getter).
    prop_info: HashMap<usize, (&'a Node, bool)>,
    /// Structure types declared as UNION ([types.derived.union]).
    unions: HashSet<usize>,
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
        "LOWER_BOUND" | "UPPER_BOUND" => Bound,
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
            global_sections: Vec::new(),
            cur_ns: None,
            qualifier: None,
            globals: Vec::new(),
            globals_def: None,
            configs: Vec::new(),
            owner: HashMap::new(),
            itf_bases: HashMap::new(),
            implements: HashMap::new(),
            abstract_fbs: HashSet::new(),
            struct_base: HashMap::new(),
            raw_alias: false,
            last_block: None,
            declare_only: HashSet::new(),
            qualifiers: HashSet::new(),
            intrinsics: HashSet::new(),
            enum_base: HashMap::new(),
            strict_enums: HashSet::new(),
            write_target: None,
            enum_hint: None,
            prop_info: HashMap::new(),
            unions: HashSet::new(),
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

    pub(crate) fn set_options(&mut self, o: &crate::Options) {
        self.declare_only = o
            .declare_only
            .iter()
            .map(|n| n.to_ascii_lowercase())
            .collect();
        self.qualifiers = o
            .qualifiers
            .iter()
            .map(|n| n.to_ascii_lowercase())
            .collect();
        self.intrinsics = o
            .intrinsics
            .iter()
            .map(|n| n.to_ascii_uppercase())
            .collect();
    }

    /// `n` is a name that qualifies a declaration (`Tc2_System` in
    /// `Tc2_System.PI`), not a variable.
    fn is_qualifier(&self, n: &'a Node) -> bool {
        if n.kind != N::NameRef {
            return false;
        }
        let Some(Item::Tok(t)) = self.items(n).first().copied() else {
            return false;
        };
        let name = self.text(t);
        self.qualifiers.contains(&name.to_ascii_lowercase())
            && self.lookup_var(name).is_none()
            && self.lookup_global(name).is_none()
    }

    /// `b` is a qualifier (`Lib`) or a chain of them (`Lib.GVL`): its path,
    /// lower case and dot separated.
    fn qualifier_path(&self, b: &'a Node) -> Option<String> {
        if self.is_qualifier(b) {
            return match self.items(b).first().copied() {
                Some(Item::Tok(t)) => Some(self.text(t).to_ascii_lowercase()),
                _ => None,
            };
        }
        if b.kind != N::MemberExpr {
            return None;
        }
        let its = self.items(b);
        let (Some(Item::Node(base)), Some(Item::Tok(m))) =
            (its.first().copied(), its.get(2).copied())
        else {
            return None;
        };
        let m = self.text(m).to_ascii_lowercase();
        if !self.qualifiers.contains(&m) {
            return None;
        }
        Some(format!("{}.{m}", self.qualifier_path(base)?))
    }

    /// [stdlib.compat.any]: an argument for an ANY input, as a
    /// __SYSTEM.AnyType value: type class, reference to the argument (a
    /// value that is not a variable is copied to a new variable), size.
    fn any_argument(&mut self, target: &Ty, v: &V) -> Option<ir::Expr> {
        let any = *self.types.get("anytype")?;
        if !self.intrinsics.contains("ANY") || *target != Ty::Named(any) {
            return None;
        }
        let vt = self.strip(&v.ty);
        if vt == Ty::Named(any) || vt == Ty::Unknown {
            return None;
        }
        let class: i128 = match &vt {
            Ty::Elem(e) => match e {
                Elem::Bool => 0,
                Elem::Byte => 2,
                Elem::Word => 3,
                Elem::Dword => 4,
                Elem::Lword => 5,
                Elem::Sint => 6,
                Elem::Int => 7,
                Elem::Dint => 8,
                Elem::Lint => 9,
                Elem::Usint => 10,
                Elem::Uint => 11,
                Elem::Udint => 12,
                Elem::Ulint => 13,
                Elem::Real => 14,
                Elem::Lreal => 15,
                Elem::Time => 18,
                Elem::Date => 19,
                Elem::Dt => 20,
                Elem::Tod => 21,
                Elem::Ltime => 37,
                _ => 28,
            },
            Ty::IntLit => 7,
            Ty::RealLit => 15,
            Ty::Str { wide: false, .. } => 16,
            Ty::Str { wide: true, .. } => 17,
            Ty::Ref(_) | Ty::Null => 23,
            Ty::Array { .. } => 26,
            Ty::Named(i) => match &self.defs[*i].kind {
                Kind::Enum(_) => 25,
                Kind::Subrange { .. } => 24,
                _ => 28,
            },
            _ => 28,
        };
        let size = self.layout(&vt, 0).map_or(0, |(s, _)| s as i128);
        let span = v.span;
        let konst = |n: i128| ir::Expr {
            ty: Ty::Elem(Elem::Dint),
            kind: ExprKind::Const(Const::Int(n)),
            span,
        };
        let place = matches!(
            v.e,
            ExprKind::Var(_)
                | ExprKind::Global(_)
                | ExprKind::Member(..)
                | ExprKind::Index(..)
                | ExprKind::Deref(_)
        ) && v.k.is_none();
        let arg = if place {
            ir::Expr {
                ty: Ty::Ref(Box::new(vt.clone())),
                kind: ExprKind::Ref(Box::new(v.clone().ir())),
                span,
            }
        } else {
            v.clone().ir()
        };
        let call = ir::Call {
            target: CallTarget::Builtin {
                name: "__ROOTPLC_ANY".into(),
                ty: Some(vt),
            },
            inputs: Vec::new(),
            outputs: Vec::new(),
            args: vec![arg, konst(class), konst(size), konst(i128::from(place))],
        };
        Some(ir::Expr {
            ty: Ty::Named(any),
            kind: ExprKind::Call(Box::new(call)),
            span,
        })
    }

    fn builtin_fb(&mut self, name: &str, inputs: &[(&str, Elem)], outputs: &[(&str, Elem)]) {
        let var = |(n, e): &(&str, Elem), section| Var {
            name: (*n).to_string(),
            ty: Ty::Elem(*e),
            section,
            span: Span::new(0, 0),
            init: None,
            alias: false,
            read_only: false,
        };
        let mut vars: Vec<Var<'a>> = inputs.iter().map(|x| var(x, Section::Input)).collect();
        vars.extend(outputs.iter().map(|x| var(x, Section::Output)));
        let pou = Pou {
            kind: PouKind::FunctionBlock,
            vars,
            ret: None,
            base: None,
            inherited: 0,
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
            self.last_block = None;
            self.collect(root);
        }
        if !self.global_sections.is_empty() {
            let id = self.add_def("<globals>", Kind::Pending, None, Span::new(0, 0));
            self.globals_def = Some(id);
            self.resolve_globals(id);
        }
        for id in 0..self.defs.len() {
            self.resolve(id);
        }
        self.check_recursion();
        for id in 0..self.defs.len() {
            self.check_def(id);
        }
        self.check_globals();
        self.check_configs();
        self.check_implements();
    }

    /// The typed IR of the project.
    pub(crate) fn into_program(mut self) -> ir::Program {
        let mut memo = HashMap::new();
        let full: Vec<Vec<Option<Init>>> = (0..self.defs.len())
            .map(|id| self.full_inits(id, &mut memo))
            .collect();
        let tables: Vec<Vec<(String, usize)>> = (0..self.defs.len())
            .map(|id| match &self.defs[id].kind {
                Kind::Pou(p) if matches!(p.kind, PouKind::FunctionBlock | PouKind::Program) => {
                    self.method_table(id)
                }
                _ => Vec::new(),
            })
            .collect();
        // [pous.oop.interface]: for __QUERYINTERFACE at run time
        let all_itfs: Vec<usize> = (0..self.defs.len())
            .filter(|&i| self.is_itf(&Ty::Named(i)))
            .collect();
        let itfs: Vec<Vec<usize>> = (0..self.defs.len())
            .map(|d| match &self.defs[d].kind {
                Kind::Pou(p) if matches!(p.kind, PouKind::FunctionBlock | PouKind::Program) => {
                    all_itfs
                        .iter()
                        .copied()
                        .filter(|&t| self.implements_itf(d, t))
                        .collect()
                }
                _ => Vec::new(),
            })
            .collect();
        let mut defs = Vec::with_capacity(self.defs.len());
        for (id, d) in self.defs.iter().enumerate() {
            let mut irs = self.irs.remove(&id).unwrap_or_default();
            irs.var_inits = full[id].clone();
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
                    if let (PouKind::Function | PouKind::Method, Some(t)) = (p.kind, &p.ret) {
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
                        owner: self.owner.get(&id).copied(),
                        declare_only: self.is_declare_only(id),
                        base: p.base,
                        methods: tables[id].clone(),
                        interfaces: itfs[id].clone(),
                    })
                }
            };
            defs.push(ir::Def {
                name: d.name.clone(),
                file: d.file,
                kind,
            });
        }
        let mut unions: Vec<usize> = self.unions.iter().copied().collect();
        unions.sort_unstable();
        ir::Program {
            defs,
            globals: self.globals_def,
            unions,
        }
    }

    /// Initial values of every slot, inherited ones taken from the base.
    fn full_inits(
        &self,
        id: usize,
        memo: &mut HashMap<usize, Vec<Option<Init>>>,
    ) -> Vec<Option<Init>> {
        if let Some(v) = memo.get(&id) {
            return v.clone();
        }
        let mut own = self
            .irs
            .get(&id)
            .map(|x| x.var_inits.clone())
            .unwrap_or_default();
        let base = match &self.defs[id].kind {
            Kind::Pou(p) => p.base.map(|b| (b, p.inherited)),
            Kind::Struct(_) => self.struct_base.get(&id).copied(),
            _ => None,
        };
        if let Some((b, count)) = base.filter(|&(b, _)| b != id) {
            let inherited = self.full_inits(b, memo);
            for (k, v) in inherited.into_iter().enumerate().take(count) {
                if let Some(slot) = own.get_mut(k) {
                    *slot = v;
                }
            }
        }
        memo.insert(id, own.clone());
        own
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
                        let name = self.items(d).into_iter().find_map(|i| match i {
                            Item::Tok(t) if self.tkind(t) != T::Keyword => Some(t),
                            _ => None,
                        });
                        if let Some(t) = name.filter(|&t| self.tkind(t) == T::Ident) {
                            let span = self.tok_span(t);
                            self.add_def(self.text(t), Kind::Pending, Some(d), span);
                        }
                    }
                }
                // [pous.namespace]: declarations inside a namespace are collected as usual
                N::Namespace => {
                    let mut parts = Vec::new();
                    for i in self.items(n) {
                        if let Item::Tok(t) = i {
                            if self.tkind(t) == T::Ident {
                                self.qualifiers.insert(self.text(t).to_ascii_lowercase());
                                parts.push(self.text(t).to_ascii_lowercase());
                            }
                        }
                    }
                    // nested namespaces: the full path, outer first
                    let path = match &self.cur_ns {
                        Some(outer) => format!("{outer}.{}", parts.join(".")),
                        None => parts.join("."),
                    };
                    let saved = self.cur_ns.replace(path);
                    self.collect(n);
                    self.cur_ns = saved;
                }
                // [pous.action]: a member after its block belongs to that block
                N::Method | N::Property | N::Action => {
                    if let Some((fb, fbname)) = self.last_block.clone() {
                        self.register_member(fb, &fbname, n);
                    }
                }
                N::Program | N::Function | N::FunctionBlock | N::Test | N::Interface => {
                    if let Some(t) = self.decl_name(n) {
                        let span = self.tok_span(t);
                        let fb = self.add_def(self.text(t), Kind::Pending, Some(n), span);
                        if matches!(n.kind, N::Program | N::FunctionBlock) {
                            self.last_block = Some((fb, self.text(t).to_string()));
                        }
                        // [pous.oop.method], [pous.action], [pous.oop.property]
                        let fbname = self.text(t).to_string();
                        for m in self.items(n) {
                            if let Item::Node(m) = m {
                                if matches!(m.kind, N::Method | N::Action | N::Property) {
                                    self.register_member(fb, &fbname, m);
                                }
                            }
                        }
                    }
                }
                N::GlobalVarList => self.collect_global_sections(n),
                N::Configuration => {
                    self.configs.push((self.cur, n));
                    self.collect_global_sections(n);
                }
                _ => {}
            }
        }
    }

    /// A method, action or property of block `fb` becomes a definition
    /// named "FB.M" (accessors "FB.P#get" / "FB.P#set").
    fn register_member(&mut self, fb: usize, fbname: &str, m: &'a Node) {
        if matches!(m.kind, N::Method | N::Action) {
            if let Some(mt) = self.decl_name(m) {
                let full = format!("{fbname}.{}", self.text(mt));
                let ms = self.tok_span(mt);
                // [pous.oop.fb-init]: run implicitly when the instance is created
                if m.kind == N::Method && self.text(mt).eq_ignore_ascii_case("FB_init") {
                    self.diag(
                        codes::VENDOR_MEANING,
                        "FB_init runs implicitly when an instance is created (CODESYS / TwinCAT); IEC 61131-3 has no initialisation method".into(),
                        ms,
                        None,
                    );
                }
                let mid = self.add_def(&full, Kind::Pending, Some(m), ms);
                self.owner.insert(mid, fb);
            }
            return;
        }
        {
            {
                // [pous.oop.property]: GET and SET become methods P#get / P#set
                for pr in [m] {
                    let Some(pt) = self.decl_name(pr) else {
                        continue;
                    };
                    let mut accs: Vec<(&'a Node, bool)> = Vec::new();
                    accs.extend(
                        self.child_nodes(pr, N::PropertyGet)
                            .into_iter()
                            .map(|a| (a, true)),
                    );
                    accs.extend(
                        self.child_nodes(pr, N::PropertySet)
                            .into_iter()
                            .map(|a| (a, false)),
                    );
                    if accs.is_empty() {
                        accs.push((pr, true)); // an interface property: its getter
                    }
                    for (acc, get) in accs {
                        let suffix = if get { "get" } else { "set" };
                        let full = format!("{fbname}.{}#{suffix}", self.text(pt));
                        let ps = self.tok_span(pt);
                        let aid = self.add_def(&full, Kind::Pending, Some(acc), ps);
                        self.owner.insert(aid, fb);
                        self.prop_info.insert(aid, (pr, get));
                    }
                }
            }
        }
    }

    /// The declared name of a POU or method: the first identifier after its
    /// keyword and any modifiers.
    fn decl_name(&self, n: &'a Node) -> Option<usize> {
        // modifiers and keywords (including PROPERTY, a plain word) come first;
        // TEST after the keyword is a name ([pous.test]); OVERRIDE, a soft
        // keyword, is a modifier when another word follows it
        let its = self.items(n);
        let next_ident = |k: usize| {
            its[k + 1..]
                .iter()
                .find_map(|i| match i {
                    Item::Tok(t) => Some(*t),
                    Item::Node(_) => None,
                })
                .is_some_and(|t| self.tkind(t) == T::Ident)
        };
        its.iter()
            .copied()
            .enumerate()
            .find_map(|(k, i)| match i {
                Item::Tok(t) if k > 0 && self.is_kw(t, "TEST") => Some(t),
                Item::Tok(t) if self.text(t).eq_ignore_ascii_case("OVERRIDE") && next_ident(k) => {
                    None
                }
                Item::Tok(t)
                    if self.tkind(t) != T::Keyword
                        && !(n.kind == N::Property
                            && self.text(t).eq_ignore_ascii_case("PROPERTY")) =>
                {
                    Some(t)
                }
                _ => None,
            })
            .filter(|&t| self.tkind(t) == T::Ident || self.is_kw(t, "TEST"))
    }

    /// Short name of a method definition ("FB.M" -> "M").
    fn method_name(&self, id: usize) -> &str {
        let n = &self.defs[id].name;
        n.rsplit_once('.').map_or(n.as_str(), |(_, m)| m)
    }

    /// Methods callable on an instance of `fb`: inherited first, overrides
    /// replacing them, [pous.oop.override].
    fn method_table(&self, fb: usize) -> Vec<(String, usize)> {
        let mut bases: Vec<usize> = match &self.defs[fb].kind {
            Kind::Pou(p) => p.base.into_iter().collect(),
            _ => Vec::new(),
        };
        bases.extend(self.itf_bases.get(&fb).cloned().unwrap_or_default());
        let mut table: Vec<(String, usize)> = Vec::new();
        for b in bases.into_iter().filter(|&b| b != fb) {
            for (n, m) in self.method_table(b) {
                if !table.iter().any(|(x, _)| x.eq_ignore_ascii_case(&n)) {
                    table.push((n, m));
                }
            }
        }
        let mut own: Vec<usize> = self
            .owner
            .iter()
            .filter(|&(_, &o)| o == fb)
            .map(|(&m, _)| m)
            .collect();
        own.sort_unstable();
        for m in own {
            let name = self.method_name(m).to_string();
            match table
                .iter_mut()
                .find(|(n, _)| n.eq_ignore_ascii_case(&name))
            {
                Some(slot) => slot.1 = m,
                None => table.push((name, m)),
            }
        }
        table
    }

    fn method_lookup(&self, fb: usize, name: &str) -> Option<usize> {
        self.method_table(fb)
            .into_iter()
            .find(|(n, _)| n.eq_ignore_ascii_case(name))
            .map(|(_, m)| m)
    }

    /// The function block or program whose instance the current scope runs on.
    fn current_fb(&self) -> Option<usize> {
        let id = self.scope?;
        match &self.defs[id].kind {
            Kind::Pou(p) if p.kind == PouKind::Method => self.owner.get(&id).copied(),
            Kind::Pou(p) if matches!(p.kind, PouKind::FunctionBlock | PouKind::Program) => Some(id),
            _ => None,
        }
    }

    /// `anc` is `fb` or one of its bases.
    fn is_self_or_base(&self, anc: usize, fb: usize) -> bool {
        let mut cur = Some(fb);
        let mut guard = 0;
        while let Some(c) = cur {
            if c == anc {
                return true;
            }
            guard += 1;
            if guard > 64 {
                return false;
            }
            cur = match &self.defs[c].kind {
                Kind::Pou(p) => p.base,
                _ => None,
            };
        }
        false
    }

    fn this_ir(&self, fb: usize, span: Span) -> ir::Expr {
        ir::Expr {
            ty: Ty::Named(fb),
            kind: ExprKind::This,
            span,
        }
    }

    /// Inside a method: a variable of its function block (inherited ones too).
    fn lookup_owner_var(&self, name: &str) -> Option<(Ty, usize, usize)> {
        let id = self.scope?;
        let Kind::Pou(m) = &self.defs[id].kind else {
            return None;
        };
        if m.kind != PouKind::Method {
            return None;
        }
        let fb = *self.owner.get(&id)?;
        let Kind::Pou(p) = &self.defs[fb].kind else {
            return None;
        };
        // the method's own VAR_INST variables first, then the block's
        let inst = format!("{}#{name}", self.method_name(id));
        let slot = p
            .vars
            .iter()
            .position(|v| v.name.eq_ignore_ascii_case(&inst))
            .or_else(|| {
                p.vars
                    .iter()
                    .position(|v| v.name.eq_ignore_ascii_case(name))
            })?;
        Some((p.vars[slot].ty.clone(), slot, fb))
    }

    /// `THIS` or `SUPER`: a reference to the current instance, typed as the
    /// block itself or its base, [pous.oop.this].
    fn this_ref(&mut self, tok: usize, span: Span) -> V {
        let word = self.text(tok).to_ascii_uppercase();
        let Some(fb) = self.current_fb() else {
            let msg = format!("{word} is only available in a function block, program or method");
            self.diag(codes::UNKNOWN_NAME, msg, span, None);
            return V::unknown(span);
        };
        let target = if word == "SUPER" {
            match &self.defs[fb].kind {
                Kind::Pou(p) if p.base.is_some() => p.base.unwrap_or(fb),
                _ => {
                    let msg = format!("'{}' has no base block (EXTENDS)", self.defs[fb].name);
                    self.diag(codes::UNKNOWN_NAME, msg, span, None);
                    return V::unknown(span);
                }
            }
        } else {
            fb
        };
        let inst = self.this_ir(target, span);
        V::with(
            Ty::Ref(Box::new(Ty::Named(target))),
            span,
            ExprKind::Ref(Box::new(inst)),
        )
    }

    /// The variable `name` of the current POU (or of block `fb`) is declared
    /// REFERENCE TO.
    fn is_alias(&self, name: &str, fb: Option<usize>) -> bool {
        let Some(id) = fb.or(self.scope) else {
            return false;
        };
        match &self.defs[id].kind {
            Kind::Pou(p) => p
                .vars
                .iter()
                .any(|v| v.alias && v.name.eq_ignore_ascii_case(name)),
            _ => false,
        }
    }

    /// [types.reference.alias]: a use of a REFERENCE TO variable is a use of
    /// its target, except in REF= and __ISVALIDREF.
    fn alias_var(&self, v: V, alias: bool) -> V {
        if !alias || self.raw_alias {
            return v;
        }
        match v.ty.clone() {
            Ty::Ref(t) => {
                let span = v.span;
                V::with(*t, span, ExprKind::Deref(Box::new(v.ir())))
            }
            _ => v,
        }
    }

    /// Whether definition `id` is declared by a compatibility library but not
    /// implemented: a listed function or block, a listed method ("FB.M"), or
    /// a method or property accessor of a listed block.
    fn is_declare_only(&self, id: usize) -> bool {
        let listed = |i: usize| {
            self.declare_only
                .contains(&self.defs[i].name.to_ascii_lowercase())
        };
        match &self.defs[id].kind {
            Kind::Pou(p) => match p.kind {
                PouKind::Function | PouKind::FunctionBlock => listed(id),
                PouKind::Method => listed(id) || self.owner.get(&id).is_some_and(|&o| listed(o)),
                _ => false,
            },
            _ => false,
        }
    }

    /// Warning RP0120 for a call of a declare-only definition.
    fn note_declare_only(&mut self, id: usize, span: Span) {
        if self.is_declare_only(id) {
            let name = self.defs[id].name.replace("#get", "").replace("#set", "");
            let msg = format!(
                "'{name}' is declared by a compatibility library but not implemented by RootPLC; running it stops with UNSUPPORTED"
            );
            self.diag(codes::DECLARE_ONLY_CALL, msg, span, None);
        }
    }

    /// A call of a property accessor (or any method) as an expression.
    #[allow(clippy::too_many_arguments)]
    fn accessor_call(
        &self,
        inst: ir::Expr,
        fb: usize,
        def: usize,
        dispatch: bool,
        inputs: Vec<(usize, ir::Expr)>,
        ty: Ty,
        span: Span,
    ) -> ir::Expr {
        let call = ir::Call {
            target: CallTarget::Method {
                inst,
                fb,
                method: def,
                name: self.method_name(def).to_string(),
                dispatch,
            },
            inputs,
            outputs: Vec::new(),
            args: Vec::new(),
        };
        ir::Expr {
            ty,
            kind: ExprKind::Call(Box::new(call)),
            span,
        }
    }

    /// `SUPER^.P`: the base expression denotes the current instance seen as
    /// a base block (no dispatch).
    fn is_super_ir(&self, e: &ir::Expr) -> bool {
        let this = match &e.kind {
            ExprKind::Deref(r) => match &r.kind {
                ExprKind::Ref(x) if matches!(x.kind, ExprKind::This) => Some(&x.ty),
                _ => None,
            },
            _ => None,
        };
        match (this, self.current_fb()) {
            (Some(Ty::Named(t)), Some(fb)) => *t != fb,
            _ => false,
        }
    }

    /// `x.P := v` or `P := v` where P is a property: a call of its setter,
    /// [pous.oop.property]. `None` when the target is not a property.
    fn property_assign(&mut self, t: &'a Node, e: &'a Node) -> Option<Stmt> {
        let span = self.span(t);
        let (inst, fb, pname) = match t.kind {
            N::MemberExpr => {
                let its = self.items(t);
                let (Some(Item::Node(b)), Some(Item::Tok(m))) =
                    (its.first().copied(), its.get(2).copied())
                else {
                    return None;
                };
                let mark = self.diags.len();
                let base = self.expr(b);
                let fb = match self.strip(&base.ty) {
                    Ty::Named(fb) => fb,
                    _ => {
                        self.diags.truncate(mark);
                        return None;
                    }
                };
                let name = self.text(m).to_string();
                if self.method_lookup(fb, &format!("{name}#set")).is_none()
                    || self.has_data_member(fb, &name)
                {
                    self.diags.truncate(mark);
                    return None;
                }
                (base.ir(), fb, name)
            }
            N::NameRef => {
                let Some(Item::Tok(i)) = self.items(t).first().copied() else {
                    return None;
                };
                let name = self.text(i).to_string();
                if self.lookup_var(&name).is_some() || self.lookup_owner_var(&name).is_some() {
                    return None;
                }
                let fb = self.current_fb()?;
                self.method_lookup(fb, &format!("{name}#set"))?;
                (self.this_ir(fb, span), fb, name)
            }
            _ => return None,
        };
        let setter = self.method_lookup(fb, &format!("{pname}#set"))?;
        let ty = match &self.defs[setter].kind {
            Kind::Pou(p) => p.vars.first().map(|v| v.ty.clone()).unwrap_or(Ty::Unknown),
            _ => Ty::Unknown,
        };
        let value = self.expr(e);
        let value = self.adapt(&ty, value);
        let dispatch = !self.is_super_ir(&inst);
        self.note_declare_only(setter, span);
        let call = self.accessor_call(
            inst,
            fb,
            setter,
            dispatch,
            vec![(0, value)],
            Ty::Unknown,
            span,
        );
        Some(Stmt::Eval(call))
    }

    /// Block or structure `id` has a variable or member called `name`.
    fn has_data_member(&self, id: usize, name: &str) -> bool {
        match &self.defs[id].kind {
            Kind::Pou(p) => p.vars.iter().any(|v| v.name.eq_ignore_ascii_case(name)),
            Kind::Struct(m) => m.iter().any(|v| v.name.eq_ignore_ascii_case(name)),
            _ => false,
        }
    }

    /// [stdlib.compat.sizeof]: size in bytes of a variable or type, with
    /// TwinCAT's 64-bit layout (8-byte packing). SIZEOF's result type grows
    /// with the size (USINT, UINT, UDINT, ULINT); XSIZEOF's is ULINT.
    fn sizeof(&mut self, up: &str, arg: &'a Node, span: Span) -> V {
        let ty = match (arg.kind, self.items(arg).first().copied()) {
            (N::NameRef, Some(Item::Tok(i))) => {
                let name = self.text(i);
                if let Some((t, _)) = self.lookup_var(name) {
                    t
                } else if let Some((t, _, _)) = self.lookup_owner_var(name) {
                    t
                } else if let Some((t, _)) = self.lookup_global(name) {
                    t
                } else if let Some(t) = elem_or_str(name) {
                    t
                } else {
                    self.type_name(i)
                }
            }
            _ => self.expr(arg).ty,
        };
        let Some((size, _)) = self.layout(&ty, 0) else {
            if ty != Ty::Unknown {
                let msg = format!(
                    "the size of {} is not known: function-block instances hold vendor-specific hidden data, and open arrays have no fixed size",
                    self.ty_name(&ty)
                );
                self.diag(codes::SIZEOF_UNKNOWN, msg, span, None);
            }
            return V::unknown(span);
        };
        let rty = if up == "XSIZEOF" {
            Elem::Ulint
        } else if size < 256 {
            Elem::Usint
        } else if size < 65_536 {
            Elem::Uint
        } else if size < 4_294_967_296 {
            Elem::Udint
        } else {
            Elem::Ulint
        };
        let v = size as i128;
        V {
            ty: Ty::Elem(rty),
            k: Some(K::Int(v)),
            leaf: false,
            span,
            e: ExprKind::Const(Const::Int(v)),
        }
    }

    /// Size and alignment in bytes with TwinCAT's default 8-byte packing:
    /// each member at an address divisible by its alignment (its size, at
    /// most 8); a structure's size is padded to its largest alignment.
    fn layout(&self, ty: &Ty, depth: usize) -> Option<(u128, u128)> {
        if depth > 32 {
            return None;
        }
        let elem = |e: Elem| -> u128 {
            use Elem::*;
            match e {
                Bool | Sint | Usint | Byte | Char => 1,
                Int | Uint | Word | Wchar => 2,
                Dint | Udint | Dword | Real | Time | Date | Tod | Dt => 4,
                Lint | Ulint | Lword | Lreal | Ltime | Ldate | Ltod | Ldt => 8,
            }
        };
        let round = |n: u128, a: u128| n.div_ceil(a.max(1)) * a.max(1);
        match ty {
            Ty::Elem(e) => {
                let s = elem(*e);
                Some((s, s))
            }
            Ty::Str { wide: false, len } => Some((u128::from(*len) + 1, 1)),
            Ty::Str { wide: true, len } => Some((2 * (u128::from(*len) + 1), 2)),
            Ty::Array { dims, elem: e } => {
                let (es, ea) = self.layout(e, depth + 1)?;
                let mut count: u128 = 1;
                for d in dims {
                    let (lo, hi) = (*d)?;
                    count *= u128::try_from(hi - lo + 1).ok()?;
                }
                Some((es * count, ea))
            }
            Ty::Ref(_) => Some((8, 8)),
            Ty::Named(id) => match &self.defs[*id].kind {
                Kind::Struct(members) => {
                    let (mut off, mut max_a) = (0u128, 1u128);
                    let union = self.unions.contains(id);
                    for m in members {
                        let (s, a) = self.layout(&m.ty, depth + 1)?;
                        let a = a.min(8);
                        // a union's members share storage: its size is the largest
                        off = if union { off.max(s) } else { round(off, a) + s };
                        max_a = max_a.max(a);
                    }
                    Some((round(off, max_a), max_a))
                }
                Kind::Enum(_) => {
                    let s = elem(self.enum_base.get(id).copied().unwrap_or(Elem::Int));
                    Some((s, s))
                }
                Kind::Subrange { base, .. } => {
                    let s = elem(*base);
                    Some((s, s))
                }
                Kind::Alias(t) => self.layout(t, depth + 1),
                Kind::Pou(p) if p.kind == PouKind::Interface => Some((8, 8)),
                _ => None,
            },
            _ => None,
        }
    }

    /// `SUPER^` as the base of a call: the base method runs without dispatch.
    fn is_super(&self, n: &'a Node) -> bool {
        n.kind == N::DerefExpr && self.first_node(n).is_some_and(|x| {
            x.kind == N::NameRef
                && matches!(self.items(x).first(), Some(Item::Tok(t)) if self.is_kw(*t, "SUPER"))
        })
    }

    /// The interfaces named in the EXTENDS or IMPLEMENTS child of `node`;
    /// names that are not interfaces are RP0111.
    fn named_list(&mut self, node: &'a Node, kind: N, must_be_itf: bool) -> Vec<usize> {
        let Some(list) = self.child_nodes(node, kind).first().copied() else {
            return Vec::new();
        };
        let toks = self.list_names(list);
        let mut out = Vec::new();
        for t in toks {
            let name = self.text(t).to_string();
            let found = self.types.get(&name.to_ascii_lowercase()).copied();
            if let Some(i) = found {
                self.resolve(i);
            }
            match found {
                Some(i) if !must_be_itf || self.is_itf(&Ty::Named(i)) => out.push(i),
                _ => {
                    let sp = self.tok_span(t);
                    self.diag(
                        codes::UNKNOWN_TYPE,
                        format!("'{name}' is not an interface"),
                        sp,
                        None,
                    );
                }
            }
        }
        out
    }

    /// The names of a comma-separated list; of a qualified name `Lib.Type`
    /// the last part, [pous.type-spec].
    fn list_names(&self, list: &'a Node) -> Vec<usize> {
        let mut out = Vec::new();
        let mut cur = None;
        for i in self.items(list) {
            if let Item::Tok(t) = i {
                match self.tkind(t) {
                    T::Ident => cur = Some(t),
                    T::Comma => out.extend(cur.take()),
                    _ => {}
                }
            }
        }
        out.extend(cur);
        out
    }

    /// [types.derived.struct]: a structure that extends another has the
    /// base's members first; their initial values come from the base.
    fn struct_extends(&mut self, id: usize, ext: &'a Node) {
        let Some(t) = self.list_names(ext).first().copied() else {
            return;
        };
        let name = self.text(t).to_string();
        let found = self.types.get(&name.to_ascii_lowercase()).copied();
        if let Some(b) = found {
            self.resolve(b);
        }
        let base_members = match found.map(|b| (b, &self.defs[b].kind)) {
            Some((b, Kind::Struct(m))) if b != id => Some((b, m.clone())),
            _ => None,
        };
        match (base_members, &self.defs[id].kind) {
            (Some((b, mut members)), Kind::Struct(own)) => {
                for m in &mut members {
                    m.init = None;
                }
                let count = members.len();
                members.extend(own.iter().cloned());
                self.defs[id].kind = Kind::Struct(members);
                self.struct_base.insert(id, (b, count));
            }
            _ => {
                let sp = self.tok_span(t);
                let msg = format!("'{name}' is not a structure that can be extended");
                self.diag(codes::UNKNOWN_TYPE, msg, sp, None);
            }
        }
    }

    /// The type is an interface.
    fn is_itf(&self, ty: &Ty) -> bool {
        matches!(ty, Ty::Named(i) if matches!(&self.defs[*i].kind, Kind::Pou(p) if p.kind == PouKind::Interface))
    }

    /// Interface `i` is `t` or extends it.
    fn itf_extends(&self, i: usize, t: usize, depth: usize) -> bool {
        i == t
            || (depth < 32
                && self
                    .itf_bases
                    .get(&i)
                    .is_some_and(|bs| bs.iter().any(|&b| self.itf_extends(b, t, depth + 1))))
    }

    /// Function block `fb` (or one of its bases) implements interface `t`.
    fn implements_itf(&self, fb: usize, t: usize) -> bool {
        let mut cur = Some(fb);
        let mut guard = 0;
        while let Some(c) = cur {
            if self
                .implements
                .get(&c)
                .is_some_and(|is| is.iter().any(|&i| self.itf_extends(i, t, 0)))
            {
                return true;
            }
            guard += 1;
            if guard > 64 {
                return false;
            }
            cur = match &self.defs[c].kind {
                Kind::Pou(p) => p.base,
                _ => None,
            };
        }
        false
    }

    /// A value for a target of type `target`: a function-block instance
    /// becomes a reference when the target is an interface it implements,
    /// [pous.oop.interface-ref]; otherwise the usual conversion rules apply.
    /// An argument for a parameter: a `REFERENCE TO T` parameter given a
    /// variable of type `T` refers to that variable ([types.reference.alias]).
    fn bind_param(&mut self, target: &Ty, alias: bool, v: V) -> ir::Expr {
        if alias {
            if let Ty::Ref(inner) = self.strip(target) {
                let place = matches!(
                    v.e,
                    ExprKind::Var(_)
                        | ExprKind::Global(_)
                        | ExprKind::Member(..)
                        | ExprKind::Index(..)
                        | ExprKind::Deref(_)
                ) && v.k.is_none();
                if place
                    && !matches!(self.strip(&v.ty), Ty::Ref(_))
                    && self.compatible(&inner, &v.ty)
                {
                    let span = v.span;
                    return ir::Expr {
                        ty: target.clone(),
                        kind: ExprKind::Ref(Box::new(v.ir())),
                        span,
                    };
                }
            }
        }
        self.adapt(target, v)
    }

    fn adapt(&mut self, target: &Ty, v: V) -> ir::Expr {
        let tt = self.strip(target);
        if let Some(e) = self.any_argument(&tt, &v) {
            return e;
        }
        if let Ty::Named(t) = tt {
            if self.is_itf(&tt) {
                let vt = self.strip(&v.ty);
                let span = v.span;
                match vt {
                    Ty::Named(s) if self.is_itf(&vt) => {
                        if !self.itf_extends(s, t, 0) {
                            self.mismatch(target, &v);
                        }
                        return v.ir();
                    }
                    Ty::Named(s) if matches!(&self.defs[s].kind, Kind::Pou(p) if matches!(p.kind, PouKind::FunctionBlock | PouKind::Program)) =>
                    {
                        if !self.implements_itf(s, t) {
                            let msg = format!(
                                "'{}' does not implement interface '{}'",
                                self.defs[s].name, self.defs[t].name
                            );
                            self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                        }
                        return ir::Expr {
                            ty: target.clone(),
                            kind: ExprKind::ToItf(Box::new(v.ir()), s),
                            span,
                        };
                    }
                    // NULL, or the TwinCAT idiom 0, clears the reference
                    Ty::Null => return v.ir(),
                    Ty::IntLit if v.k == Some(K::Int(0)) => {
                        let msg = "0 used as an interface reference; IEC 61131-3 writes NULL";
                        self.diag(codes::INTEGER_AS_BOOL_OR_NULL, msg.into(), v.span, None);
                        return ir::Expr {
                            ty: Ty::Null,
                            kind: ExprKind::Null,
                            span,
                        };
                    }
                    _ => {}
                }
            }
        }
        self.coerce(target, &v);
        v.ir()
    }

    /// IMPLEMENTS: every method of every named interface exists, unless the
    /// block is ABSTRACT, [pous.oop.implements].
    fn check_implements(&mut self) {
        let saved = self.cur;
        let mut list: Vec<(usize, Vec<usize>)> = self.implements.clone().into_iter().collect();
        list.sort_unstable();
        for (fb, itfs) in list {
            if self.abstract_fbs.contains(&fb) {
                continue;
            }
            for itf in itfs {
                for (name, _) in self.method_table(itf) {
                    if self.method_lookup(fb, &name).is_none() {
                        self.cur = self.defs[fb].file;
                        let what = match name.split_once('#') {
                            Some((p, acc)) => {
                                format!("property '{p}' ({})", acc.to_ascii_uppercase())
                            }
                            None => format!("method '{name}'"),
                        };
                        let msg = format!(
                            "'{}' does not implement {what} of interface '{}'",
                            self.defs[fb].name, self.defs[itf].name
                        );
                        let sp = self.defs[fb].span;
                        self.diag(codes::UNKNOWN_NAME, msg, sp, None);
                    }
                }
            }
        }
        self.cur = saved;
    }

    /// VAR_GLOBAL sections of a global list, a configuration or its resources.
    fn collect_global_sections(&mut self, n: &'a Node) {
        for s in self.child_nodes(n, N::VarSection) {
            let its = self.items(s);
            let global = matches!(its.first(), Some(Item::Tok(t)) if self.is_kw(*t, "VAR_GLOBAL"));
            let constant = its
                .iter()
                .take(5)
                .any(|i| matches!(i, Item::Tok(t) if self.is_kw(*t, "CONSTANT")));
            if global {
                self.global_sections
                    .push((self.cur, s, constant, self.cur_ns.clone()));
            }
        }
        for r in self.child_nodes(n, N::Resource) {
            self.collect_global_sections(r);
        }
    }

    /// Types and constant values of the global variables, in declaration order,
    /// so a constant can use the constants declared before it.
    fn resolve_globals(&mut self, id: usize) {
        let saved = self.cur;
        let mut vars = Vec::new();
        for (file, sec, constant, ns) in self.global_sections.clone() {
            self.cur = file;
            for d in self.child_nodes(sec, N::VarDecl) {
                let start = vars.len();
                self.var_decl(d, Section::Local, &mut vars);
                for v in &vars[start..] {
                    let value = if constant {
                        v.init
                            .and_then(|i| self.first_node(i))
                            .and_then(|e| self.const_int(e))
                    } else {
                        None
                    };
                    self.globals.push(GlobalVar {
                        file,
                        name: v.name.clone(),
                        value,
                        ns: ns.clone(),
                    });
                }
            }
        }
        self.cur = saved;
        self.defs[id].kind = Kind::Pou(Pou {
            kind: PouKind::FunctionBlock,
            vars,
            ret: None,
            base: None,
            inherited: 0,
        });
    }

    /// Initial values and unique names of the global variables, [config.global-list].
    fn check_globals(&mut self) {
        let Some(id) = self.globals_def else { return };
        let Kind::Pou(p) = self.defs[id].kind.clone() else {
            return;
        };
        let saved = self.cur;
        self.scope = None;
        let mut out = DefIr::default();
        let mut seen = HashSet::new();
        for (k, v) in p.vars.iter().enumerate() {
            self.cur = self.globals[k].file;
            // [config.global-list]: names are unique within a namespace
            let key = (self.globals[k].ns.clone(), v.name.to_ascii_lowercase());
            if !seen.insert(key) {
                let msg = format!("'{}' is already declared as a global variable", v.name);
                self.diag(codes::DUPLICATE_NAME, msg, v.span, None);
            }
            let init = v.init.and_then(|i| self.initializer(&v.ty, i));
            out.var_inits.push(init);
        }
        self.cur = saved;
        self.irs.insert(id, out);
    }

    /// Program instances name a PROGRAM and a declared task, [config.program-instance].
    fn check_configs(&mut self) {
        let saved = self.cur;
        for (file, node) in self.configs.clone() {
            self.cur = file;
            self.check_config_scope(node);
        }
        self.cur = saved;
    }

    fn check_config_scope(&mut self, node: &'a Node) {
        let tasks: Vec<String> = self
            .child_nodes(node, N::TaskConfig)
            .into_iter()
            .filter_map(|t| {
                // skip the word TASK itself (an identifier token, [lexical.keywords.soft])
                self.items(t).iter().skip(1).find_map(|i| match i {
                    Item::Tok(k) if self.tkind(*k) == T::Ident => {
                        Some(self.text(*k).to_ascii_lowercase())
                    }
                    _ => None,
                })
            })
            .collect();
        for pc in self.child_nodes(node, N::ProgramConfig) {
            let its = self.items(pc);
            let (mut task, mut ty, mut after_with, mut after_colon) = (None, None, false, false);
            for it in &its {
                if let Item::Tok(t) = *it {
                    if self.text(t).eq_ignore_ascii_case("WITH") {
                        after_with = true;
                    } else if self.tkind(t) == T::Colon {
                        after_colon = true;
                    } else if self.tkind(t) == T::Ident {
                        if after_colon && ty.is_none() {
                            ty = Some(t);
                        } else if after_with && task.is_none() && !after_colon {
                            task = Some(t);
                        }
                    }
                }
            }
            if let Some(t) = ty {
                let name = self.text(t);
                let is_program = self.types.get(&name.to_ascii_lowercase()).is_some_and(
                    |&id| matches!(&self.defs[id].kind, Kind::Pou(p) if p.kind == PouKind::Program),
                );
                if !is_program {
                    let span = self.tok_span(t);
                    let msg = format!("unknown program '{name}'");
                    let hint =
                        Some("a program instance needs a PROGRAM declared in the project".into());
                    self.diag(codes::UNKNOWN_NAME, msg, span, hint);
                }
            }
            if let Some(t) = task {
                if !tasks.contains(&self.text(t).to_ascii_lowercase()) {
                    let span = self.tok_span(t);
                    let msg = format!("unknown task '{}'", self.text(t));
                    self.diag(codes::UNKNOWN_NAME, msg, span, None);
                }
            }
        }
        for r in self.child_nodes(node, N::Resource) {
            self.check_config_scope(r);
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
            if let Some(ext) = find(N::Extends) {
                self.struct_extends(id, ext);
            }
            return;
        }
        if let Some(&(prop, get)) = self.prop_info.get(&id) {
            // [pous.oop.property]: getter returns the property type; the
            // setter's first input, named like the property, is the value
            let ty = self
                .child_nodes(prop, N::TypeSpec)
                .first()
                .copied()
                .map_or(Ty::Unknown, |s| self.type_spec(s, None));
            let mut vars = Vec::new();
            if !get {
                if let Some(pt) = self.decl_name(prop) {
                    vars.push(Var {
                        name: self.text(pt).to_string(),
                        ty: ty.clone(),
                        section: Section::Input,
                        span: self.tok_span(pt),
                        init: None,
                        alias: false,
                        read_only: false,
                    });
                }
            }
            if !std::ptr::eq(node, prop) {
                for s in self.child_nodes(node, N::VarSection) {
                    for d in self.child_nodes(s, N::VarDecl) {
                        self.var_decl(d, Section::Local, &mut vars);
                    }
                }
            }
            self.defs[id].kind = Kind::Pou(Pou {
                kind: PouKind::Method,
                vars,
                ret: if get { Some(ty) } else { None },
                base: None,
                inherited: 0,
            });
            return;
        }
        if node.kind == N::Interface {
            // [pous.oop.interface]: the interfaces it extends
            let bases = self.named_list(node, N::Extends, true);
            self.itf_bases.insert(id, bases);
            self.defs[id].kind = Kind::Pou(Pou {
                kind: PouKind::Interface,
                vars: Vec::new(),
                ret: None,
                base: None,
                inherited: 0,
            });
            return;
        }
        if node.kind == N::FunctionBlock {
            let itfs = self.named_list(node, N::Implements, true);
            self.implements.insert(id, itfs);
            if self
                .items(node)
                .iter()
                .any(|i| matches!(i, Item::Tok(t) if self.is_kw(*t, "ABSTRACT")))
            {
                self.abstract_fbs.insert(id);
            }
        }
        let kind = match node.kind {
            N::Program => PouKind::Program,
            N::Function => PouKind::Function,
            N::FunctionBlock => PouKind::FunctionBlock,
            N::Method | N::Action => PouKind::Method,
            _ => PouKind::Test,
        };
        let (mut vars, mut ret, mut base) = (Vec::new(), None, None);
        // [pous.oop.extends]: the base block's variables come first
        if let Some(ext) = self.child_nodes(node, N::Extends).first().copied() {
            let name = self.list_names(ext).first().copied();
            if let Some(t) = name {
                let bname = self.text(t);
                let found = self.types.get(&bname.to_ascii_lowercase()).copied();
                if let Some(b) = found {
                    self.resolve(b);
                }
                match found.map(|b| (b, &self.defs[b].kind)) {
                    Some((b, Kind::Pou(bp)))
                        if matches!(bp.kind, PouKind::FunctionBlock) && b != id =>
                    {
                        vars = bp.vars.clone();
                        base = Some(b);
                    }
                    _ => {
                        let sp = self.tok_span(t);
                        let msg = format!("'{bname}' is not a function block that can be extended");
                        self.diag(codes::UNKNOWN_TYPE, msg, sp, None);
                    }
                }
            }
        }
        let inherited = vars.len();
        // [pous.oop.method]: VAR_INST variables of the block's methods keep their
        // value between calls: they are stored in the instance as "M#name"
        let mut inst_vars = Vec::new();
        if matches!(node.kind, N::FunctionBlock | N::Program) {
            for m in self.child_nodes(node, N::Method) {
                let Some(mt) = self.decl_name(m) else {
                    continue;
                };
                let mname = self.text(mt).to_string();
                for s in self.child_nodes(m, N::VarSection) {
                    let is_inst = matches!(self.items(s).first(), Some(Item::Tok(t)) if self.text(*t).eq_ignore_ascii_case("VAR_INST"));
                    if !is_inst {
                        continue;
                    }
                    for d in self.child_nodes(s, N::VarDecl) {
                        let start = inst_vars.len();
                        self.var_decl(d, Section::Local, &mut inst_vars);
                        for v in &mut inst_vars[start..] {
                            v.name = format!("{mname}#{}", v.name);
                        }
                    }
                }
            }
        }
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
                            // [config.external]: names the global variable itself
                            "VAR_EXTERNAL" => continue,
                            // [pous.oop.method]: VAR_INST lives in the block (see below)
                            "VAR_INST" if node.kind == N::Method => continue,
                            // [variables.section]: VAR PUBLIC is visible from outside
                            "VAR"
                                if self.items(n).iter().take(5).any(
                                    |i| matches!(i, Item::Tok(t) if self.is_kw(*t, "PUBLIC")),
                                ) =>
                            {
                                Section::Input
                            }
                            _ => Section::Local,
                        },
                        _ => Section::Local,
                    };
                    // [pous.vendor.in-out-constant]: VAR_IN_OUT CONSTANT takes values too
                    let read_only = section == Section::InOut
                        && self
                            .items(n)
                            .iter()
                            .take(5)
                            .any(|i| matches!(i, Item::Tok(t) if self.is_kw(*t, "CONSTANT")));
                    let start = vars.len();
                    for d in self.child_nodes(n, N::VarDecl) {
                        self.var_decl(d, section, &mut vars);
                    }
                    for v in &mut vars[start..] {
                        v.read_only = read_only;
                        // [pous.call.in-out]: a STRING parameter takes the
                        // caller's whole text; the caller's length applies
                        // when it is written back
                        if let (Section::InOut, Ty::Str { len, .. }) = (section, &mut v.ty) {
                            *len = 65_535;
                        }
                    }
                }
                _ => {}
            }
        }
        vars.extend(inst_vars);
        self.defs[id].kind = Kind::Pou(Pou {
            kind,
            vars,
            ret,
            base,
            inherited,
        });
    }

    fn var_decl(&mut self, d: &'a Node, section: Section, out: &mut Vec<Var<'a>>) {
        let its = self.items(d);
        let mut names = Vec::new();
        let (mut spec, mut init) = (None, None);
        let mut before_colon = true;
        for it in &its {
            match *it {
                Item::Tok(t) if self.tkind(t) == T::Colon => before_colon = false,
                // x AT %IX0.0: AT is the word before the address, not a name
                Item::Tok(t) if self.tkind(t) == T::DirectVariable => {
                    if names
                        .last()
                        .is_some_and(|&a| self.text(a).eq_ignore_ascii_case("AT"))
                    {
                        names.pop();
                    }
                }
                Item::Tok(t)
                    if before_colon
                        && (self.tkind(t) == T::Ident
                            || self.is_kw(t, "TEST")
                            || self.is_kw(t, "NULL")
                            || self.is_kw(t, "REF")) =>
                {
                    names.push(t)
                }
                Item::Node(n) if n.kind == N::TypeSpec => spec = Some(n),
                Item::Node(n) if n.kind == N::Initializer => init = Some(n),
                _ => {}
            }
        }
        let ty = spec.map_or(Ty::Unknown, |s| self.type_spec(s, None));
        if init.is_none() {
            init = spec.and_then(|s| self.type_default(s));
        }
        let alias = spec.is_some_and(|s| {
            matches!(self.items(s).first(), Some(Item::Tok(t)) if self.text(*t).eq_ignore_ascii_case("REFERENCE"))
        });
        for t in names {
            out.push(Var {
                name: self.text(t).to_string(),
                ty: ty.clone(),
                section,
                span: self.tok_span(t),
                init,
                alias,
                read_only: false,
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
                        Item::Tok(t)
                            if self.tkind(t) == T::LBracket
                                || (self.tkind(t) == T::LParen && matches!(ty, Ty::Str { .. })) =>
                        {
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
                            let base = match ty {
                                Ty::Elem(b) => Some(b),
                                _ => None,
                            };
                            ty = self.enum_type(e, decl);
                            if let (Some(b), Ty::Named(id)) = (base, &ty) {
                                self.enum_base.insert(*id, b);
                            }
                            k += 1;
                        }
                        _ => k += 1,
                    }
                }
                ty
            }
            // [types.reference]: POINTER TO T is read as REF_TO T; REFERENCE TO T too
            // (its variables are aliases, see `alias_var`)
            Item::Tok(i)
                if (self.text(i).eq_ignore_ascii_case("POINTER")
                    || self.text(i).eq_ignore_ascii_case("REFERENCE"))
                    && matches!(its.get(1), Some(Item::Tok(t)) if self.is_kw(*t, "TO")) =>
            {
                match its.get(2).copied() {
                    Some(Item::Node(s)) => Ty::Ref(Box::new(self.type_spec(s, None))),
                    _ => Ty::Unknown,
                }
            }
            // Lib.Type: the last part names the type
            Item::Tok(i) if self.tkind(i) == T::Ident => {
                let last = its
                    .iter()
                    .rev()
                    .find_map(|x| match x {
                        Item::Tok(t) if self.tkind(*t) == T::Ident => Some(*t),
                        _ => None,
                    })
                    .unwrap_or(i);
                self.type_name(last)
            }
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
                    let union = matches!(self.items(e).first(), Some(Item::Tok(t))
                        if self.text(*t).eq_ignore_ascii_case("UNION"));
                    let ty = self.make_def(decl, Kind::Struct(members));
                    if let (true, Ty::Named(id)) = (union, &ty) {
                        self.unions.insert(*id);
                    }
                    ty
                }
                _ => Ty::Unknown,
            },
            Item::Tok(_) => Ty::Unknown,
        }
    }

    fn type_name(&mut self, i: usize) -> Ty {
        let name = self.text(i);
        let span = self.tok_span(i);
        // [stdlib.compat.pvoid]: an untyped reference; any REF_TO (ADR(x))
        // converts to it
        if name.eq_ignore_ascii_case("PVOID") && self.intrinsics.contains("PVOID") {
            return Ty::Ref(Box::new(Ty::Unknown));
        }
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
        // [stdlib.compat.any]: with TwinCAT_BuiltIns an ANY input is a
        // __SYSTEM.AnyType (type class, address, size)
        if GENERIC_TYPES.iter().any(|g| g.eq_ignore_ascii_case(name))
            && self.intrinsics.contains("ANY")
        {
            if let Some(&id) = self.types.get("anytype") {
                return Ty::Named(id);
            }
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
        let id_ty = self.make_def(decl, Kind::Enum(values));
        // [types.derived.enum.integer]: {attribute 'strict'} before the name
        if let Ty::Named(id) = id_ty {
            let before = &self.src()[..self.span(e).start as usize];
            let from = ["END_TYPE", "END_STRUCT", ";"]
                .iter()
                .filter_map(|m| before.rfind(m).map(|i| i + m.len()))
                .max()
                .unwrap_or(0);
            if before[from..].to_ascii_lowercase().contains("'strict'") {
                self.strict_enums.insert(id);
            }
        }
        // [types.derived.enum]: the vendor spelling with the base type after the values
        let trailing = self.items(e).into_iter().find_map(|i| match i {
            Item::Tok(t) if self.tkind(t) == T::TypeName => Elem::from_name(self.text(t)),
            _ => None,
        });
        if let (Some(b), Ty::Named(id)) = (trailing, &id_ty) {
            self.enum_base.insert(*id, b);
        }
        id_ty
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
            N::NameRef => match its.first().copied() {
                Some(Item::Tok(i)) if self.lookup_var(self.text(i)).is_none() => {
                    let name = self.text(i);
                    self.globals
                        .iter()
                        .find(|g| g.name.eq_ignore_ascii_case(name))
                        .and_then(|g| g.value)
                }
                _ => None,
            },
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
                for (k, v) in p.vars.iter().enumerate() {
                    // inherited variables: their initial values come from the base
                    let init = if k < p.inherited {
                        None
                    } else {
                        v.init.and_then(|i| self.initializer(&v.ty, i))
                    };
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
                let mut items = Vec::new();
                for c in self.child_nodes(inner, N::Initializer) {
                    // [variables.initializer]: n(v) repeats v n times; n() the default
                    if let Some((count, value)) = self.repeated_element(c) {
                        let init = match value {
                            Some(e) => {
                                let v = self.expr_expecting(&elem, e);
                                self.coerce(&elem, &v);
                                Init::Expr(v.ir())
                            }
                            None => Init::Struct(Vec::new()),
                        };
                        items.extend(std::iter::repeat_n(init, count));
                        continue;
                    }
                    if let Some(i) = self.initializer(&elem, c) {
                        items.push(i);
                    }
                }
                Some(Init::Array(items))
            }
            N::StructInit => {
                // [variables.initializer]: a function-block instance takes the
                // same form for its variables (TON := (PT := T#1S)), CODESYS /
                // TwinCAT; `()` keeps every default
                let members = match ty {
                    Ty::Named(i) => match &self.defs[*i].kind {
                        Kind::Struct(m) => m.clone(),
                        Kind::Pou(p) if p.kind == PouKind::FunctionBlock => p.vars.clone(),
                        _ => Vec::new(),
                    },
                    Ty::Unknown => return None,
                    _ => Vec::new(),
                };
                let structured = matches!(ty, Ty::Named(i)
                    if matches!(&self.defs[*i].kind, Kind::Struct(_) | Kind::Pou(_)));
                if structured && self.child_nodes(inner, N::Initializer).is_empty() {
                    return Some(Init::Struct(Vec::new()));
                }
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
                let v = self.expr_expecting(ty, inner);
                self.coerce(ty, &v);
                Some(Init::Expr(v.ir()))
            }
        }
    }

    /// An array initializer element `n(v)` / `n()`: the count and the value
    /// expression ([variables.initializer]).
    fn repeated_element(&mut self, c: &'a Node) -> Option<(usize, Option<&'a Node>)> {
        let e = self.first_node(c)?;
        if e.kind != N::CallExpr {
            return None;
        }
        let its = self.items(e);
        let (Some(Item::Node(callee)), Some(Item::Node(list))) =
            (its.first().copied(), its.get(1).copied())
        else {
            return None;
        };
        // the count: an integer literal, or a constant expression such as
        // SIZEOF(buffer) (TwinCAT); never a name, which would be a call
        let count = match callee.kind {
            N::Literal => {
                let Some(Item::Tok(t)) = self.items(callee).first().copied() else {
                    return None;
                };
                if self.tkind(t) != T::Integer {
                    return None;
                }
                literal::parse_int(self.text(t))?
            }
            N::NameRef | N::MemberExpr => return None,
            _ => match self.expr(callee).k {
                Some(K::Int(n)) => {
                    let span = self.span(callee);
                    self.diag(
                        codes::VENDOR_MEANING,
                        "a constant expression as repetition count is a TwinCAT form; IEC 61131-3 writes an integer literal".into(),
                        span,
                        None,
                    );
                    n
                }
                _ => return None,
            },
        };
        let count = usize::try_from(count).ok()?;
        let args = self.args(list);
        match args.as_slice() {
            [] => Some((count, None)),
            [a] if a.name.is_none() => Some((count, Some(a.expr))),
            _ => None,
        }
    }

    fn stmt_list(&mut self, n: &'a Node) -> Vec<Stmt> {
        let mut out = Vec::new();
        for it in self.items(n) {
            if let Item::Node(s) = it {
                self.stmt_into(s, &mut out);
            }
        }
        out
    }

    /// One statement; a chain `a := b := v` ([statements.assignment.chain])
    /// becomes `b := v; a := b;`.
    fn stmt_into(&mut self, s: &'a Node, out: &mut Vec<Stmt>) {
        let its = self.items(s);
        if let (N::AssignStmt, Some(Item::Node(t)), Some(Item::Tok(op)), Some(Item::Node(inner))) = (
            s.kind,
            its.first().copied(),
            its.get(1).copied(),
            its.get(2).copied(),
        ) {
            if self.tkind(op) == T::Assign && inner.kind == N::AssignStmt {
                let span = self.span(s);
                self.diag(
                    codes::CHAINED_ASSIGNMENT,
                    "chained assignment is a vendor form; IEC 61131-3 writes one assignment per statement".into(),
                    span,
                    None,
                );
                self.stmt_into(inner, out);
                let Some(Item::Node(source)) = self.items(inner).first().copied() else {
                    return;
                };
                let target = self.expr(t);
                let value = self.expr(source);
                let value = self.adapt(&target.ty, value);
                out.push(Stmt::Assign(target.ir(), value));
                return;
            }
        }
        if let Some(st) = self.stmt(s) {
            out.push(st);
        }
    }

    fn stmt(&mut self, n: &'a Node) -> Option<Stmt> {
        let its = self.items(n);
        match n.kind {
            N::AssignStmt if matches!(its.get(1), Some(Item::Tok(t)) if self.is_kw(*t, "REF")) => {
                // [types.reference.alias]: r REF= x makes r refer to x
                let (Some(Item::Node(t)), Some(Item::Node(e))) =
                    (its.first().copied(), its.get(3).copied())
                else {
                    return None;
                };
                self.raw_alias = true;
                let target = self.expr(t);
                self.raw_alias = false;
                let value = self.expr(e);
                let r = V::with(
                    Ty::Ref(Box::new(value.ty.clone())),
                    value.span,
                    ExprKind::Ref(Box::new(value.ir())),
                );
                self.coerce(&target.ty, &r);
                Some(Stmt::Assign(target.ir(), r.ir()))
            }
            N::AssignStmt
                if matches!(its.get(1), Some(Item::Tok(t))
                    if self.tkind(*t) == T::Ident && matches!(self.text(*t), "S" | "s" | "R" | "r")) =>
            {
                // [statements.assignment.set-reset]: x S= c is IF c THEN x := TRUE
                let (Some(Item::Node(t)), Some(Item::Tok(op)), Some(Item::Node(e))) = (
                    its.first().copied(),
                    its.get(1).copied(),
                    its.get(3).copied(),
                ) else {
                    return None;
                };
                let set = self.text(op).eq_ignore_ascii_case("S");
                let span = self.span(n);
                let msg = format!(
                    "'{}=' is a vendor spelling; IEC 61131-3 writes IF ... THEN ... := {}; END_IF",
                    self.text(op).to_ascii_uppercase(),
                    if set { "TRUE" } else { "FALSE" }
                );
                self.diag(codes::SET_RESET_ASSIGN, msg, span, None);
                let target = self.expr(t);
                self.coerce(&Ty::Elem(Elem::Bool), &target);
                let cond = self.condition(e);
                let value = ir::Expr {
                    ty: Ty::Elem(Elem::Bool),
                    kind: ExprKind::Const(Const::Bool(set)),
                    span,
                };
                Some(Stmt::If(
                    vec![(cond, vec![Stmt::Assign(target.ir(), value)])],
                    Vec::new(),
                ))
            }
            N::AssignStmt => {
                let (Some(Item::Node(t)), Some(Item::Tok(op)), Some(Item::Node(e))) = (
                    its.first().copied(),
                    its.get(1).copied(),
                    its.get(2).copied(),
                ) else {
                    return None;
                };
                if self.tkind(op) == T::Assign {
                    if let Some(st) = self.property_assign(t, e) {
                        return Some(st);
                    }
                }
                let saved = self.write_target.replace(self.span(t));
                let target = self.expr(t);
                self.write_target = saved;
                let value = self.expr_expecting(&target.ty, e);
                let value = if self.tkind(op) == T::Assign {
                    self.adapt(&target.ty, value)
                } else {
                    value.ir()
                };
                Some(Stmt::Assign(target.ir(), value))
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
                // [statements.for]: the control variable is a place: a variable,
                // or (TwinCAT) an array element or member
                let ctrl_node = match its.get(1).copied() {
                    Some(Item::Node(c)) if c.kind != N::StmtList => Some(c),
                    _ => None,
                };
                if let Some(c) = ctrl_node {
                    let v = self.expr(c);
                    let ok = match self.strip(&v.ty) {
                        Ty::Elem(e) => e.is_int(),
                        Ty::Unknown => true,
                        _ => false,
                    };
                    let is_place = matches!(
                        v.e,
                        ExprKind::Var(_)
                            | ExprKind::Global(_)
                            | ExprKind::Member(..)
                            | ExprKind::Index(..)
                            | ExprKind::Deref(_)
                            | ExprKind::Invalid
                    );
                    if !ok || !is_place {
                        let msg = format!(
                            "the FOR control variable must be an integer variable, not {}",
                            self.ty_name(&v.ty)
                        );
                        self.diag(codes::IMPLICIT_CONVERSION, msg, v.span, None);
                        ctrl = V::unknown(v.span);
                    } else {
                        ctrl = v;
                    }
                }
                let mut exprs = Vec::new();
                let mut body = Vec::new();
                for it in its
                    .iter()
                    .skip(if ctrl_node.is_some() { 2 } else { 0 })
                    .copied()
                {
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
        let v = match sel {
            Some(s) => {
                let st = s.ty.clone();
                self.expr_expecting(&st, e)
            }
            None => self.expr(e),
        };
        if let Some(s) = sel {
            let st = s.ty.clone();
            self.coerce(&st, &v);
        }
        match v.k {
            Some(K::Int(n)) => Some(n),
            _ => None,
        }
    }

    /// [stdlib.functions.operators]: ADD, SUB, ..., GT, ... as functions:
    /// the same IR as the operators. `None` when `up` is not one of them.
    fn operator_function(&mut self, up: &str, args: &[Arg<'a>], span: Span) -> Option<V> {
        let (op, cmp, variadic) = match up {
            "ADD" => (BinOp::Add, false, true),
            "MUL" => (BinOp::Mul, false, true),
            "SUB" => (BinOp::Sub, false, false),
            "DIV" => (BinOp::Div, false, false),
            "MOD" => (BinOp::Mod, false, false),
            "GT" => (BinOp::Gt, true, true),
            "GE" => (BinOp::Ge, true, true),
            "EQ" => (BinOp::Eq, true, true),
            "LE" => (BinOp::Le, true, true),
            "LT" => (BinOp::Lt, true, true),
            "NE" => (BinOp::Ne, true, false),
            _ => return None,
        };
        let vals: Vec<V> = args.iter().map(|a| self.expr(a.expr)).collect();
        if vals.len() < 2 || (!variadic && vals.len() != 2) {
            let want = if variadic { "two or more" } else { "two" };
            let msg = format!("{up} takes {want} arguments, found {}", vals.len());
            self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
            return Some(V::unknown(span));
        }
        let what = format!("'{up}'");
        let bin = |op: BinOp, opty: Ty, l: ir::Expr, r: ir::Expr| ExprKind::Binary {
            op,
            opty,
            l: Box::new(l),
            r: Box::new(r),
        };
        if cmp {
            // a > b AND b > c ...
            let mut acc: Option<ir::Expr> = None;
            for w in vals.windows(2) {
                let t = match self.unify(&w[0], &w[1], &what) {
                    Ty::Unknown => return Some(V::unknown(span)),
                    Ty::IntLit => Ty::Elem(Elem::Dint),
                    Ty::RealLit => Ty::Elem(Elem::Lreal),
                    t => t,
                };
                let e = ir::Expr {
                    ty: Ty::Elem(Elem::Bool),
                    kind: bin(op, t, w[0].clone().ir(), w[1].clone().ir()),
                    span,
                };
                acc = Some(match acc {
                    None => e,
                    Some(a) => ir::Expr {
                        ty: Ty::Elem(Elem::Bool),
                        kind: bin(BinOp::And, Ty::Elem(Elem::Bool), a, e),
                        span,
                    },
                });
            }
            let e = acc?;
            return Some(V::with(Ty::Elem(Elem::Bool), span, e.kind));
        }
        let mut it = vals.into_iter();
        let mut acc = it.next()?;
        for v in it {
            let t = self.unify(&acc, &v, &what);
            let st = self.strip(&t);
            let num = matches!(st, Ty::IntLit | Ty::RealLit)
                || matches!(st, Ty::Elem(e) if e.is_num()
                    || (e.is_duration() && matches!(op, BinOp::Add | BinOp::Sub)));
            if !num {
                if t != Ty::Unknown {
                    let msg = format!("{up} is not defined for {}", self.ty_name(&t));
                    self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                }
                return Some(V::unknown(span));
            }
            // two constants fold to a constant, as with the operators
            let folded = match (acc.k, v.k) {
                (Some(K::Int(a)), Some(K::Int(b))) => match op {
                    BinOp::Add => a.checked_add(b).map(K::Int),
                    BinOp::Sub => a.checked_sub(b).map(K::Int),
                    BinOp::Mul => a.checked_mul(b).map(K::Int),
                    BinOp::Div if b != 0 => Some(K::Int(a / b)),
                    BinOp::Mod if b != 0 => Some(K::Int(a % b)),
                    _ => None,
                },
                (Some(K::Real(a)), Some(K::Real(b))) => match op {
                    BinOp::Add => Some(K::Real(a + b)),
                    BinOp::Sub => Some(K::Real(a - b)),
                    BinOp::Mul => Some(K::Real(a * b)),
                    BinOp::Div => Some(K::Real(a / b)),
                    _ => None,
                },
                _ => None,
            };
            let st = match (folded.is_some(), st) {
                (false, Ty::IntLit) => Ty::Elem(Elem::Dint),
                (false, Ty::RealLit) => Ty::Elem(Elem::Lreal),
                (_, t) => t,
            };
            let e = bin(op, st.clone(), acc.ir(), v.ir());
            acc = V::with(st, span, e);
            acc.k = folded;
        }
        Some(acc)
    }

    /// [types.time.arith]: `+` / `-` on a time of day, date or date-and-time
    /// with a duration, or the difference of two of them. Lowered to the VM
    /// function __ROOTPLC_TIME_ARITH(a, b, kind, sign), which scales units
    /// (DATE / DT in s, TOD / TIME in ms, L types in ns).
    fn time_arith(&mut self, minus: bool, l: &V, r: &V, span: Span) -> Option<V> {
        use Elem::*;
        let (Ty::Elem(a), Ty::Elem(b)) = (self.strip(&l.ty), self.strip(&r.ty)) else {
            return None;
        };
        // (kind, result type); kind 1 TOD±TIME, 2 DT±TIME, 3 DATE-DATE,
        // 4 TOD-TOD, 5 DT-DT, 6 LTOD±LTIME, 7 LDT±LTIME, 8 same-type
        // difference of L types (ns)
        let (kind, res) = match (a, b, minus) {
            (Tod, Time, _) => (1, Tod),
            (Dt, Time, _) => (2, Dt),
            (Date, Date, true) => (3, Time),
            (Tod, Tod, true) => (4, Time),
            (Dt, Dt, true) => (5, Time),
            (Ltod, Ltime, _) => (6, Ltod),
            (Ldt, Ltime, _) => (7, Ldt),
            (Ldate, Ldate, true) | (Ltod, Ltod, true) | (Ldt, Ldt, true) => (8, Ltime),
            _ => return None,
        };
        let lit = |n: i128| ir::Expr {
            ty: Ty::Elem(Dint),
            kind: ExprKind::Const(Const::Int(n)),
            span,
        };
        let call = ir::Call {
            target: CallTarget::Builtin {
                name: "__ROOTPLC_TIME_ARITH".into(),
                ty: None,
            },
            inputs: Vec::new(),
            outputs: Vec::new(),
            args: vec![
                l.clone().ir(),
                r.clone().ir(),
                lit(kind),
                lit(if minus { -1 } else { 1 }),
            ],
        };
        Some(V::with(Ty::Elem(res), span, ExprKind::Call(Box::new(call))))
    }

    /// `n` evaluated where a value of type `ty` is expected: an unqualified
    /// enumeration value then resolves to that enumeration ([types.derived.enum]).
    fn expr_expecting(&mut self, ty: &Ty, n: &'a Node) -> V {
        let st = self.strip(ty);
        let hint = match st {
            Ty::Named(i) if self.is_enum(&st) => Some(i),
            _ => None,
        };
        let saved = std::mem::replace(&mut self.enum_hint, hint);
        let v = self.expr(n);
        self.enum_hint = saved;
        v
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
        let is_result = match p.kind {
            PouKind::Function => self.defs[id].name.eq_ignore_ascii_case(name),
            PouKind::Method => self
                .method_name(id)
                .trim_end_matches("#get")
                .eq_ignore_ascii_case(name),
            _ => false,
        };
        if is_result {
            return p.ret.clone().map(|t| (t, p.vars.len()));
        }
        None
    }

    /// [pous.call.in-out]: the argument of a VAR_IN_OUT parameter must be a variable.
    fn check_in_out_arg(&mut self, param: &Var<'a>, arg: &ir::Expr) {
        let (section, name) = (param.section, param.name.as_str());
        if param.read_only {
            return;
        }
        use ir::ExprKind as K;
        let is_var = matches!(
            arg.kind,
            K::Var(_)
                | K::Global(_)
                | K::This
                | K::ToItf(..)
                | K::Member(..)
                | K::Index(..)
                | K::Deref(_)
                | K::Invalid
        );
        if section == Section::InOut && !is_var {
            self.diag(
                codes::IN_OUT_NOT_VARIABLE,
                format!("VAR_IN_OUT parameter '{name}' needs a variable, not a value"),
                arg.span,
                None,
            );
        }
    }

    /// A global variable: type and slot, [variables.resolution].
    fn lookup_global(&self, name: &str) -> Option<(Ty, usize)> {
        let cands: Vec<usize> = (0..self.globals.len())
            .filter(|&k| self.globals[k].name.eq_ignore_ascii_case(name))
            .collect();
        // GVL_A.x picks the x of namespace GVL_A; x alone the one outside any
        // namespace, else the first ([pous.namespace])
        let in_ns = |k: &usize, q: &str| {
            self.globals[*k]
                .ns
                .as_deref()
                .is_some_and(|ns| ns == q || ns.ends_with(&format!(".{q}")))
        };
        let slot = match &self.qualifier {
            Some(q) => cands
                .iter()
                .find(|k| in_ns(k, q))
                .or(cands.first())
                .copied()?,
            None => cands
                .iter()
                .find(|k| self.globals[**k].ns.is_none())
                .or(cands.first())
                .copied()?,
        };
        match &self.defs[self.globals_def?].kind {
            Kind::Pou(p) => Some((p.vars.get(slot)?.ty.clone(), slot)),
            _ => None,
        }
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
            many if many.iter().any(|(id, _)| Some(*id) == self.enum_hint) => {
                let &(id, v) = many
                    .iter()
                    .find(|(id, _)| Some(*id) == self.enum_hint)
                    .unwrap_or(&many[0]);
                Some(V {
                    ty: Ty::Named(id),
                    k: Some(K::Int(v)),
                    leaf: true,
                    span,
                    e: ExprKind::Invalid,
                })
            }
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

    /// The base type of enumeration type `t` (INT unless declared).
    fn enum_base_of(&self, t: &Ty) -> Option<Elem> {
        match t {
            Ty::Named(i) if self.is_enum(t) => {
                Some(self.enum_base.get(i).copied().unwrap_or(Elem::Int))
            }
            _ => None,
        }
    }

    fn is_strict_enum(&self, t: &Ty) -> bool {
        matches!(t, Ty::Named(i) if self.strict_enums.contains(i))
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
                    // CODESYS / TwinCAT: 0 / 1 as BOOL, 0 as a null reference;
                    // warning RP0127
                    Ty::Elem(Elem::Bool) if matches!(v.k, Some(K::Int(0 | 1))) => {
                        let msg = "integer literal used as BOOL; IEC 61131-3 writes FALSE or TRUE";
                        self.diag(codes::INTEGER_AS_BOOL_OR_NULL, msg.into(), v.span, None);
                        true
                    }
                    // the TwinCAT idiom 0 for an empty interface reference
                    Ty::Named(_) if self.is_itf(&tb) && v.k == Some(K::Int(0)) => {
                        let msg = "0 used as an interface reference; IEC 61131-3 writes NULL";
                        self.diag(codes::INTEGER_AS_BOOL_OR_NULL, msg.into(), v.span, None);
                        true
                    }
                    // [types.derived.enum.integer]: a constant stored in an enumeration
                    Ty::Named(i) if self.is_enum(&tb) => {
                        let listed = matches!(&self.defs[*i].kind, Kind::Enum(vals)
                            if vals.iter().any(|(_, x)| Some(K::Int(*x)) == v.k));
                        if listed || !self.is_strict_enum(&tb) {
                            let msg = format!(
                                "integer stored in enumeration {}; IEC 61131-3 names the value",
                                self.ty_name(to)
                            );
                            self.diag(codes::ENUM_AS_INTEGER, msg, v.span, None);
                            true
                        } else {
                            self.mismatch(to, v);
                            false
                        }
                    }
                    Ty::Ref(_) if v.k == Some(K::Int(0)) => {
                        let msg = "0 used as a reference; IEC 61131-3 writes NULL";
                        self.diag(codes::INTEGER_AS_BOOL_OR_NULL, msg.into(), v.span, None);
                        true
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
                let ok = matches!(tb, Ty::Ref(_)) || self.is_itf(&tb);
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
            // [types.derived.enum.integer]: an enumeration value as an integer,
            // or an integer / other enumeration stored in a non-strict one
            let fb = self.strip(&v.ty);
            if self.is_enum(&fb) && int_like(&tb) {
                let msg = format!(
                    "enumeration {} used as {}; IEC 61131-3 converts explicitly",
                    self.ty_name(&v.ty),
                    self.ty_name(to)
                );
                self.diag(codes::ENUM_AS_INTEGER, msg, v.span, None);
                return true;
            }
            if self.is_enum(&tb)
                && !self.is_strict_enum(&tb)
                && (int_like(&fb) || self.is_enum(&fb))
            {
                let msg = format!(
                    "{} stored in enumeration {}; IEC 61131-3 converts explicitly",
                    self.ty_name(&v.ty),
                    self.ty_name(to)
                );
                self.diag(codes::ENUM_AS_INTEGER, msg, v.span, None);
                return true;
            }
            // CODESYS / TwinCAT: UDINT to DWORD and back (same size); RP0126
            if let (Ty::Elem(a), Ty::Elem(b)) = (&tb, self.strip(&v.ty)) {
                if same_size_bits(*a, b).is_some() {
                    let msg = format!(
                        "{} converted implicitly to {}; IEC 61131-3 converts explicitly",
                        b.name(),
                        a.name()
                    );
                    self.diag(codes::BIT_STRING_AS_NUMBER, msg, v.span, None);
                    return true;
                }
            }
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
            // [types.derived.enum.integer]: an enumeration with an integer constant
            (Ty::IntLit, t) | (t, Ty::IntLit) if self.is_enum(t) => {
                let b = self.enum_base_of(t).unwrap_or(Elem::Int);
                let msg = format!(
                    "operands of {what} mix {} and {} as integers; IEC 61131-3 converts explicitly",
                    self.ty_name(&l.ty),
                    self.ty_name(&r.ty)
                );
                let span = Span::new(l.span.start as usize, r.span.end as usize);
                self.diag(codes::ENUM_AS_INTEGER, msg, span, None);
                Ty::Elem(b)
            }
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
            // CODESYS / TwinCAT: an unsigned integer and a bit string of the
            // same size mix (DWORD XOR UDINT); warning RP0126
            (Ty::Elem(a), Ty::Elem(b)) if same_size_bits(*a, *b).is_some() => {
                let msg = format!(
                    "operands of {what} mix {} and {}; IEC 61131-3 converts explicitly",
                    a.name(),
                    b.name()
                );
                let span = Span::new(l.span.start as usize, r.span.end as usize);
                self.diag(codes::BIT_STRING_AS_NUMBER, msg, span, None);
                Ty::Elem(same_size_bits(*a, *b).unwrap_or(*a))
            }
            // [types.derived.enum.integer]: compared (or computed) as integers
            _ if (self.is_enum(&lt) || self.is_enum(&rt))
                && [&lt, &rt].iter().all(|t| self.is_enum(t) || int_like(t)) =>
            {
                let msg = format!(
                    "operands of {what} mix {} and {} as integers; IEC 61131-3 converts explicitly",
                    self.ty_name(&l.ty),
                    self.ty_name(&r.ty)
                );
                let span = Span::new(l.span.start as usize, r.span.end as usize);
                self.diag(codes::ENUM_AS_INTEGER, msg, span, None);
                let base = |t: &Ty| match t {
                    Ty::Elem(e) => Some(*e),
                    _ => self.enum_base_of(t),
                };
                match (base(&lt), base(&rt)) {
                    (Some(a), Some(b)) if a.widens_to(b) => Ty::Elem(b),
                    (Some(a), _) => Ty::Elem(a),
                    _ => Ty::Elem(Elem::Dint),
                }
            }
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

    /// A name used as a value, [variables.resolution].
    fn name_ref(&mut self, i: usize, span: Span) -> V {
        if self.is_kw(i, "THIS") || self.is_kw(i, "SUPER") {
            return self.this_ref(i, span);
        }
        let name = self.text(i);
        if let Some((t, slot)) = self.lookup_var(name) {
            let v = V::with(t, span, ExprKind::Var(slot));
            return self.alias_var(v, self.is_alias(name, None));
        }
        if let Some((t, slot, fb)) = self.lookup_owner_var(name) {
            let inst = self.this_ir(fb, span);
            let v = V::with(t, span, ExprKind::Member(Box::new(inst), slot));
            return self.alias_var(v, self.is_alias(name, Some(fb)));
        }
        if let Some(fb) = self.current_fb() {
            if let Some(getter) = self.method_lookup(fb, &format!("{name}#get")) {
                let ty = match &self.defs[getter].kind {
                    Kind::Pou(p) => p.ret.clone().unwrap_or(Ty::Unknown),
                    _ => Ty::Unknown,
                };
                let inst = self.this_ir(fb, span);
                self.note_declare_only(getter, span);
                let call = self.accessor_call(inst, fb, getter, true, Vec::new(), ty.clone(), span);
                return V::with(ty, span, call.kind);
            }
        }
        if let Some((t, slot)) = self.lookup_global(name) {
            let mut v = V::with(t, span, ExprKind::Global(slot));
            // a CONSTANT global with a known value is a constant
            v.k = self.globals[slot].value.map(K::Int);
            return v;
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

    fn expr(&mut self, n: &'a Node) -> V {
        let span = self.span(n);
        let its = self.items(n);
        match n.kind {
            N::Literal => match its.first().copied() {
                Some(Item::Tok(i)) => self.literal(i),
                _ => V::unknown(span),
            },
            N::NameRef => match its.first().copied() {
                Some(Item::Tok(i)) => self.name_ref(i, span),
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
        let lt = l.ty.clone();
        let r = self.expr_expecting(&lt, rn);
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
        // [pous.oop.interface-ref]: itf = other, itf <> NULL, itf <> 0
        if matches!(bop, BinOp::Eq | BinOp::Ne)
            && (self.is_itf(&self.strip(&l.ty)) || self.is_itf(&self.strip(&r.ty)))
        {
            let other_ok = |v: &V, me: &Self| {
                let t = me.strip(&v.ty);
                me.is_itf(&t) || t == Ty::Null || (t == Ty::IntLit && v.k == Some(K::Int(0)))
            };
            if other_ok(&l, self) && other_ok(&r, self) {
                for v in [&l, &r] {
                    if self.strip(&v.ty) == Ty::IntLit {
                        let msg = "0 compared with an interface reference; IEC 61131-3 writes NULL";
                        self.diag(codes::INTEGER_AS_BOOL_OR_NULL, msg.into(), v.span, None);
                    }
                }
                let opty = if self.is_itf(&self.strip(&l.ty)) {
                    l.ty.clone()
                } else {
                    r.ty.clone()
                };
                let e = ExprKind::Binary {
                    op: bop,
                    opty,
                    l: Box::new(l.ir()),
                    r: Box::new(r.ir()),
                };
                return V::with(Ty::Elem(Elem::Bool), span, e);
            }
        }
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
        // [types.time.arith]: TOD + TIME, DT - DT, ...
        if matches!(opk, T::Plus | T::Minus) {
            if let Some(v) = self.time_arith(opk == T::Minus, &l, &r, span) {
                return v;
            }
        }
        // [types.derived.enum.integer]: no arithmetic on a strict enumeration
        if cls != Cls::Cmp {
            let strict = [&l.ty, &r.ty]
                .into_iter()
                .map(|t| self.strip(t))
                .find(|t| self.is_strict_enum(t));
            if let Some(t) = strict {
                let msg = format!(
                    "operator {what} is not defined for {} (declared with attribute 'strict')",
                    self.ty_name(&t)
                );
                self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
                return V::unknown(span);
            }
        }
        let ty = self.unify(&l, &r, &what);
        if ty == Ty::Unknown {
            return V::unknown(span);
        }
        let mut st = self.strip(&ty);
        // [types.derived.enum.integer]: arithmetic on a non-strict enumeration
        if cls != Cls::Cmp && !self.is_strict_enum(&st) {
            if let Some(b) = self.enum_base_of(&st) {
                let msg = format!(
                    "operator {what} on enumeration {}; IEC 61131-3 converts first",
                    self.ty_name(&ty)
                );
                self.diag(codes::ENUM_AS_INTEGER, msg, span, None);
                st = Ty::Elem(b);
            }
        }
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
        // CODESYS / TwinCAT: arithmetic on bit strings (DWORD + 1) and
        // bitwise operators on integers; warning RP0126
        let vendor = !ok
            && match cls {
                Cls::Arith | Cls::Mod => {
                    matches!(st, Ty::Elem(e) if e.is_bit() && e != Elem::Bool)
                }
                Cls::Logic => matches!(st, Ty::Elem(e) if e.is_int()),
                _ => false,
            };
        if vendor {
            let msg = format!(
                "operator {what} on {} is a vendor extension; IEC 61131-3 converts first",
                self.ty_name(&ty)
            );
            self.diag(codes::BIT_STRING_AS_NUMBER, msg, span, None);
        }
        let ok = ok || vendor;
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
        if let Some(q) = self.qualifier_path(b) {
            // [stdlib.compat]: Tc2_System.PI names PI; [pous.namespace]:
            // Outer.Inner.x the x of the nested namespace
            let saved = self.qualifier.replace(q);
            let v = self.name_ref(m, span);
            self.qualifier = saved;
            return v;
        }
        if let Some(id) = self.enum_type_ref(b) {
            // [types.enum]: E.V, also qualified (NS.E.V), names a value of E
            let text = format!("{}#{}", self.defs[id].name, self.text(m));
            let v = self.enum_literal(&text, span);
            if v.k.is_some() {
                let msg = format!("enumeration value written with '.'; IEC 61131-3 writes {text}");
                self.diag(codes::ENUM_DOT_VALUE, msg, span, None);
            }
            return v;
        }
        let writing = self.write_target == Some(span);
        let saved = self.write_target;
        if writing {
            self.write_target = Some(self.span(b));
        }
        let base = self.expr(b);
        self.write_target = saved;
        self.member_on_rw(base, m, span, writing)
    }

    /// `b` names an enumeration type (`E`, `NS.E`) rather than a variable.
    fn enum_type_ref(&self, b: &'a Node) -> Option<usize> {
        let ident = |it: Option<&Item<'a>>| match it.copied() {
            Some(Item::Tok(t)) if self.tkind(t) == T::Ident => Some(self.text(t)),
            _ => None,
        };
        let its = self.items(b);
        let last = match b.kind {
            N::NameRef => ident(its.first())?,
            N::MemberExpr => ident(its.get(2))?,
            _ => return None,
        };
        // the leftmost name must not be a variable
        let mut left = b;
        while left.kind == N::MemberExpr {
            match self.items(left).first().copied() {
                Some(Item::Node(n)) => left = n,
                _ => return None,
            }
        }
        if left.kind != N::NameRef {
            return None;
        }
        let first = ident(self.items(left).first())?;
        if self.lookup_var(first).is_some() || self.lookup_global(first).is_some() {
            return None;
        }
        let &id = self.types.get(&last.to_ascii_lowercase())?;
        matches!(self.defs[id].kind, Kind::Enum(_)).then_some(id)
    }

    fn member_on(&mut self, base: V, m: usize, span: Span) -> V {
        self.member_on_rw(base, m, span, false)
    }

    fn member_on_rw(&mut self, base: V, m: usize, span: Span, writing: bool) -> V {
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
        // THIS^.x: an instance's own variables, also inherited ones
        let own = self
            .current_fb()
            .is_some_and(|f| self.is_self_or_base(id, f));
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
                        (whitebox || v.section != Section::Local || own)
                            && v.name.eq_ignore_ascii_case(name)
                    })
                    .map(|i| (i, p.vars[i].ty.clone())),
            ),
            _ => None,
        };
        if matches!(found, Some(None) | None) {
            // [pous.oop.property]: reading a property calls its getter
            if let Some(getter) = self.method_lookup(id, &format!("{name}#get")) {
                let ty = match &self.defs[getter].kind {
                    Kind::Pou(p) => p.ret.clone().unwrap_or(Ty::Unknown),
                    _ => Ty::Unknown,
                };
                let inst = base.ir();
                let dispatch = !self.is_super_ir(&inst);
                self.note_declare_only(getter, span);
                let call =
                    self.accessor_call(inst, id, getter, dispatch, Vec::new(), ty.clone(), span);
                return V::with(ty, span, call.kind);
            }
        }
        // [pous.call.local-read]: TwinCAT / CODESYS read internal variables
        // of an instance from outside; writing them stays an error
        let local = match (&found, &self.defs[id].kind) {
            (Some(None), Kind::Pou(p)) if !writing => p
                .vars
                .iter()
                .position(|v| v.name.eq_ignore_ascii_case(name))
                .filter(|&i| p.vars[i].section == Section::Local)
                .map(|i| (i, p.vars[i].ty.clone())),
            _ => None,
        };
        let found = match local {
            Some(hit) => {
                let msg = format!(
                    "internal variable '{name}' of '{tname}' read from outside; IEC 61131-3 allows only inputs and outputs"
                );
                self.diag(codes::BLOCK_LOCAL_READ, msg, self.tok_span(m), None);
                Some(Some(hit))
            }
            None => found,
        };
        match found {
            Some(Some((i, t))) => V::with(t, span, ExprKind::Member(Box::new(base.ir()), i)),
            Some(None) => {
                let what = if matches!(self.defs[id].kind, Kind::Struct(_)) {
                    "member"
                } else {
                    "input or output"
                };
                let internal = writing
                    && matches!(&self.defs[id].kind, Kind::Pou(p)
                        if p.vars.iter().any(|v| v.name.eq_ignore_ascii_case(name)));
                let msg = if internal {
                    format!(
                        "internal variable '{name}' of '{tname}' cannot be written from outside"
                    )
                } else {
                    format!("'{tname}' has no {what} '{name}'")
                };
                let sp = self.tok_span(m);
                self.diag(codes::UNKNOWN_NAME, msg, sp, None);
                V::unknown(span)
            }
            None => V::unknown(span),
        }
    }

    fn index(&mut self, its: &[Item<'a>], span: Span) -> V {
        let Some(Item::Node(b)) = its.first().copied() else {
            return V::unknown(span);
        };
        let saved = self.write_target;
        self.write_target = (saved == Some(span)).then(|| self.span(b));
        let base = self.expr(b);
        self.write_target = None;
        let mut idx = Vec::new();
        for it in &its[1..] {
            if let Item::Node(e) = *it {
                let v = self.expr(e);
                let st = self.strip(&v.ty);
                let ok = matches!(st, Ty::IntLit | Ty::Unknown)
                    || matches!(st, Ty::Elem(e) if e.is_int());
                // CODESYS / TwinCAT index with BYTE, WORD, ...: warning RP0126
                let bits = matches!(st, Ty::Elem(e) if e.is_bit() && e != Elem::Bool);
                if bits {
                    let msg = format!(
                        "array index of type {} is a vendor extension; IEC 61131-3 indexes with integers",
                        self.ty_name(&st)
                    );
                    self.diag(codes::BIT_STRING_AS_NUMBER, msg, self.span(e), None);
                }
                if !ok && !bits {
                    let msg = format!(
                        "array index must be an integer, found {}",
                        self.ty_name(&v.ty)
                    );
                    self.diag(codes::IMPLICIT_CONVERSION, msg, v.span, None);
                }
                idx.push(v);
            }
        }
        self.write_target = saved;
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
                (Some(Item::Tok(n)), Some(Item::Tok(op)))
                    if self.tkind(n) == T::Ident || self.is_kw(n, "TEST") =>
                {
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
        if callee.kind == N::MemberExpr {
            let its = self.items(callee);
            if let (Some(Item::Node(b)), Some(Item::Tok(m))) =
                (its.first().copied(), its.get(2).copied())
            {
                if self.is_qualifier(b) {
                    // [stdlib.compat]: Tc2_System.ADSLOGSTR(...)
                    return self.call_named(m, &args, span);
                }
                let base = self.expr(b);
                // [pous.oop.method]: inst.M(...), THIS^.M(...), SUPER^.M(...)
                if let Ty::Named(fb) = self.strip(&base.ty) {
                    if let Some(mdef) = self.method_lookup(fb, self.text(m)) {
                        let dispatch = !self.is_super(b);
                        let ms = self.tok_span(m);
                        let recv = Some((base.ir(), fb, dispatch));
                        return self.bind_call(V::of(Ty::Named(mdef), ms), &args, span, recv);
                    }
                }
                let cspan = self.span(callee);
                let mv = self.member_on(base, m, cspan);
                return self.bind_call(mv, &args, span, None);
            }
        }
        if callee.kind != N::NameRef {
            let b = self.expr(callee);
            return self.bind_call(b, &args, span, None);
        }
        let Some(Item::Tok(i)) = self.items(callee).first().copied() else {
            return V::unknown(span);
        };
        self.call_named(i, &args, span)
    }

    /// A call of a named function, block instance or method.
    fn call_named(&mut self, i: usize, args: &[Arg<'a>], span: Span) -> V {
        let name = self.text(i);
        let cspan = self.tok_span(i);
        // a variable that cannot be called does not hide a function of the
        // same name (OSCAT: DAY_OF_MONTH the function and a member)
        let function = self.types.get(&name.to_ascii_lowercase()).copied().filter(
            |&id| matches!(&self.defs[id].kind, Kind::Pou(p) if p.kind == PouKind::Function),
        );
        let callable = |me: &Self, t: &Ty| {
            matches!(me.strip(t), Ty::Named(id) if matches!(me.defs[id].kind, Kind::Pou(_)))
                || matches!(me.strip(t), Ty::Ref(ref r) if matches!(me.strip(r), Ty::Named(id) if matches!(me.defs[id].kind, Kind::Pou(_))))
        };
        if let (Some(id), Some((t, _))) = (function, self.lookup_var(name)) {
            if !callable(self, &t) {
                return self.bind_call(V::of(Ty::Named(id), cspan), args, span, None);
            }
        }
        // [types.reference.alias]: a REFERENCE TO an instance calls the instance
        if let Some((t, slot)) = self.lookup_var(name) {
            let v = V::with(t, cspan, ExprKind::Var(slot));
            let v = self.alias_var(v, self.is_alias(name, None));
            return self.bind_call(v, args, span, None);
        }
        if let Some((t, slot, fb)) = self.lookup_owner_var(name) {
            let inst = self.this_ir(fb, cspan);
            let v = V::with(t, cspan, ExprKind::Member(Box::new(inst), slot));
            let v = self.alias_var(v, self.is_alias(name, Some(fb)));
            return self.bind_call(v, args, span, None);
        }
        // a method of the current block, called without THIS^
        if let Some(fb) = self.current_fb() {
            if let Some(mdef) = self.method_lookup(fb, name) {
                let recv = Some((self.this_ir(fb, cspan), fb, true));
                return self.bind_call(V::of(Ty::Named(mdef), cspan), args, span, recv);
            }
        }
        if let Some(&id) = self.types.get(&name.to_ascii_lowercase()) {
            if matches!(&self.defs[id].kind, Kind::Pou(p) if p.kind == PouKind::Function) {
                return self.bind_call(V::of(Ty::Named(id), cspan), args, span, None);
            }
        }
        let up = name.to_ascii_uppercase();
        // [stdlib.compat.dynamic]: __NEW(T [, n]) creates a variable (n
        // elements) and returns a reference to it; __DELETE(p) frees it
        // and sets p to NULL
        if up == "__NEW" && self.intrinsics.contains(&up) && (1..=2).contains(&args.len()) {
            let tnode = args[0].expr;
            let ty = match (tnode.kind, self.items(tnode).first().copied()) {
                (N::NameRef, Some(Item::Tok(i))) => {
                    let name = self.text(i);
                    elem_or_str(name).unwrap_or_else(|| self.type_name(i))
                }
                _ => {
                    self.diag(
                        codes::UNKNOWN_TYPE,
                        "__NEW expects a type name".into(),
                        span,
                        None,
                    );
                    Ty::Unknown
                }
            };
            let mut call_args = Vec::new();
            if let Some(a) = args.get(1) {
                let n = self.expr(a.expr);
                self.coerce(&Ty::Elem(Elem::Udint), &n);
                call_args.push(n.ir());
            }
            let call = ir::Call {
                target: CallTarget::Builtin {
                    name: "__NEW".into(),
                    ty: Some(ty.clone()),
                },
                inputs: Vec::new(),
                outputs: Vec::new(),
                args: call_args,
            };
            return V::with(Ty::Ref(Box::new(ty)), span, ExprKind::Call(Box::new(call)));
        }
        // [stdlib.compat.query]: __QUERYINTERFACE(src, itf) / __QUERYPOINTER(src, p)
        if (up == "__QUERYINTERFACE" || up == "__QUERYPOINTER")
            && self.intrinsics.contains(&up)
            && args.len() == 2
        {
            let src = self.expr(args[0].expr);
            let st = self.strip(&src.ty);
            let src_ir = match st {
                Ty::Named(fb) if matches!(&self.defs[fb].kind, Kind::Pou(p) if matches!(p.kind, PouKind::FunctionBlock | PouKind::Program)) =>
                {
                    let span = src.span;
                    let ty = src.ty.clone();
                    ir::Expr {
                        ty,
                        kind: ExprKind::ToItf(Box::new(src.ir()), fb),
                        span,
                    }
                }
                _ => src.ir(),
            };
            let dst = self.expr(args[1].expr);
            let dt = self.strip(&dst.ty);
            let ok = if up == "__QUERYINTERFACE" {
                self.is_itf(&dt) || dt == Ty::Unknown
            } else {
                matches!(dt, Ty::Ref(_) | Ty::Unknown)
            };
            if !ok {
                let msg = format!(
                    "{up} needs {} as its second argument, found {}",
                    if up == "__QUERYINTERFACE" {
                        "an interface variable"
                    } else {
                        "a pointer"
                    },
                    self.ty_name(&dst.ty)
                );
                self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
            }
            let addr = ir::Expr {
                ty: Ty::Ref(Box::new(dst.ty.clone())),
                kind: ExprKind::Ref(Box::new(dst.ir())),
                span,
            };
            let call = ir::Call {
                target: CallTarget::Builtin {
                    name: up.to_string(),
                    ty: Some(dt),
                },
                inputs: Vec::new(),
                outputs: Vec::new(),
                args: vec![src_ir, addr],
            };
            return V::with(Ty::Elem(Elem::Bool), span, ExprKind::Call(Box::new(call)));
        }
        if up == "__DELETE" && self.intrinsics.contains(&up) && args.len() == 1 {
            let p = self.expr(args[0].expr);
            let pty = self.strip(&p.ty);
            if !matches!(pty, Ty::Ref(_) | Ty::Unknown) {
                let msg = format!(
                    "__DELETE expects a reference, found {}",
                    self.ty_name(&p.ty)
                );
                self.diag(codes::IMPLICIT_CONVERSION, msg, span, None);
            }
            let addr = ir::Expr {
                ty: Ty::Ref(Box::new(p.ty.clone())),
                kind: ExprKind::Ref(Box::new(p.ir())),
                span,
            };
            let call = ir::Call {
                target: CallTarget::Builtin {
                    name: "__DELETE".into(),
                    ty: None,
                },
                inputs: Vec::new(),
                outputs: Vec::new(),
                args: vec![addr],
            };
            return V::with(Ty::Unknown, span, ExprKind::Call(Box::new(call)));
        }
        // [stdlib.compat.intrinsics]: __POUNAME() is the name of the POU it
        // is written in; TIME() the time since the PLC started (VM clock)
        if args.is_empty() && self.intrinsics.contains(&up) && up == "__POUNAME" {
            let name = self
                .scope
                .map(|d| self.defs[d].name.clone())
                .unwrap_or_default();
            let ty = Ty::Str {
                wide: false,
                len: crate::types::DEFAULT_STRING_LEN.max(name.len() as u32),
            };
            return V::with(ty, span, ExprKind::Const(Const::Str(name)));
        }
        if args.is_empty() && self.intrinsics.contains(&up) && up == "TIME" {
            let call = ir::Call {
                target: CallTarget::Builtin {
                    name: "TIME".into(),
                    ty: None,
                },
                inputs: Vec::new(),
                outputs: Vec::new(),
                args: Vec::new(),
            };
            return V::with(Ty::Elem(Elem::Time), span, ExprKind::Call(Box::new(call)));
        }
        if (up == "SIZEOF" || up == "XSIZEOF")
            && self.intrinsics.contains(&up)
            && args.len() == 1
            && args[0].name.is_none()
        {
            return self.sizeof(&up, args[0].expr, span);
        }
        if up == "__ISVALIDREF" && args.len() == 1 && args[0].name.is_none() {
            // [types.reference.alias]: the reference is set (not NULL)
            self.raw_alias = true;
            let v = self.expr(args[0].expr);
            self.raw_alias = false;
            let null = ir::Expr {
                ty: Ty::Null,
                kind: ExprKind::Null,
                span,
            };
            let e = ExprKind::Binary {
                op: BinOp::Ne,
                opty: v.ty.clone(),
                l: Box::new(v.ir()),
                r: Box::new(null),
            };
            return V::with(Ty::Elem(Elem::Bool), span, e);
        }
        if up == "ADR" && args.len() == 1 && args[0].name.is_none() {
            // [types.reference]: CODESYS ADR(x) is read as REF(x)
            self.diag(
                codes::ADR_FUNCTION,
                "ADR is a vendor function; RootPLC reads it as REF (no pointer arithmetic)".into(),
                cspan,
                None,
            );
            let v = self.expr(args[0].expr);
            return V::with(
                Ty::Ref(Box::new(v.ty.clone())),
                span,
                ExprKind::Ref(Box::new(v.ir())),
            );
        }
        if let Some(v) = self.operator_function(&up, args, span) {
            return v;
        }
        if let Some(b) = builtin(&up) {
            return self.builtin_call(&up, b, args, span);
        }
        self.diag(
            codes::UNKNOWN_NAME,
            format!("unknown function '{name}'"),
            cspan,
            None,
        );
        for a in args {
            self.expr(a.expr);
        }
        V::unknown(span)
    }

    /// Call of a function-block or program instance (`callee` is a place),
    /// or of a user function (`callee` has the function's type, no place).
    fn bind_call(
        &mut self,
        callee: V,
        args: &[Arg<'a>],
        span: Span,
        recv: Option<(ir::Expr, usize, bool)>,
    ) -> V {
        let pou = match self.strip(&callee.ty) {
            Ty::Named(id) => match &self.defs[id].kind {
                Kind::Pou(p) => Some((id, self.defs[id].name.clone(), p.clone())),
                _ => None,
            },
            _ => None,
        };
        let Some((id, pname, p)) = pou else {
            // [pous.call.callee]
            if callee.ty != Ty::Unknown {
                let msg = format!(
                    "a value of type {} cannot be called; only functions, function block instances, programs, methods and actions",
                    self.ty_name(&callee.ty)
                );
                self.diag(codes::NOT_CALLABLE, msg, callee.span, None);
            }
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
                            let val = self.expr_expecting(&p.vars[s].ty, a.expr);
                            let ir = self.bind_param(&p.vars[s].ty, p.vars[s].alias, val);
                            self.check_in_out_arg(&p.vars[s], &ir);
                            inputs.push((s, ir));
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
                    let want = input_slots
                        .get(pos)
                        .map_or(Ty::Unknown, |&s| p.vars[s].ty.clone());
                    let val = self.expr_expecting(&want, a.expr);
                    if let Some(&s) = input_slots.get(pos) {
                        let ir = self.bind_param(&p.vars[s].ty, p.vars[s].alias, val);
                        self.check_in_out_arg(&p.vars[s], &ir);
                        inputs.push((s, ir));
                    }
                }
            }
        }
        self.note_declare_only(id, span);
        let (target, ty) = if let Some((inst, fb, dispatch)) = recv {
            (
                CallTarget::Method {
                    inst,
                    fb,
                    method: id,
                    name: self.method_name(id).to_string(),
                    dispatch,
                },
                p.ret.clone().unwrap_or(Ty::Unknown),
            )
        } else if p.kind == PouKind::Function {
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
        if matches!(b, Builtin::Bound) {
            return self.bound_call(up, vals, span);
        }
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
            // handled by bound_call before this match
            Builtin::Bound => (Ty::Elem(Elem::Dint), None),
            Builtin::StrFn => {
                let wide = matches!(
                    vals.first().map(|v| self.strip(&v.ty)),
                    Some(Ty::Str { wide: true, .. })
                );
                // [stdlib.string.length]: long enough for any result, so
                // nothing is cut before the assignment
                let lens: Vec<u32> = vals
                    .iter()
                    .map(|v| match (&v.k, self.strip(&v.ty)) {
                        (Some(K::Str(n)), _) => u32::try_from(*n).unwrap_or(u32::MAX),
                        (_, Ty::Str { len, .. }) => len,
                        _ => DEFAULT_STRING_LEN,
                    })
                    .collect();
                let at = |i: usize| lens.get(i).copied().unwrap_or(0);
                let len = match up {
                    "CONCAT" => lens.iter().fold(0u32, |a, &b| a.saturating_add(b)),
                    "INSERT" | "REPLACE" => at(0).saturating_add(at(1)),
                    _ => at(0),
                };
                (
                    Ty::Str {
                        wide,
                        len: len.clamp(1, 65_535),
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

impl<'a> Checker<'a> {
    /// [stdlib.functions.bounds]: `LOWER_BOUND(arr, dim)` / `UPPER_BOUND(arr, dim)`,
    /// DINT. A constant for an array with known bounds; for an open array
    /// (`ARRAY[*]`) the bounds of the array passed in, at run time.
    fn bound_call(&mut self, up: &str, vals: Vec<V>, span: Span) -> V {
        let dint = Ty::Elem(Elem::Dint);
        if vals.len() != 2 {
            let msg = format!("{up} takes an array and a dimension number");
            self.diag(codes::UNKNOWN_NAME, msg, span, None);
            return V::unknown(span);
        }
        let dims = match self.strip(&vals[0].ty) {
            Ty::Array { dims, .. } => dims,
            Ty::Unknown => return V::unknown(span),
            other => {
                let msg = format!("{up} needs an array, not {}", self.ty_name(&other));
                self.diag(codes::IMPLICIT_CONVERSION, msg, vals[0].span, None);
                return V::unknown(span);
            }
        };
        let Some(K::Int(d)) = vals[1].k else {
            let msg = format!("the dimension number of {up} must be a constant");
            self.diag(codes::IMPLICIT_CONVERSION, msg, vals[1].span, None);
            return V::unknown(span);
        };
        if d < 1 || d as usize > dims.len() {
            let msg = format!("{up}: the array has {} dimension(s), not {d}", dims.len());
            self.diag(codes::CONSTANT_INDEX_OUT_OF_BOUNDS, msg, vals[1].span, None);
            return V::unknown(span);
        }
        if let Some((lo, hi)) = dims[d as usize - 1] {
            let v = if up == "LOWER_BOUND" { lo } else { hi };
            return V {
                ty: dint,
                k: Some(K::Int(v)),
                leaf: false,
                span,
                e: ExprKind::Const(Const::Int(v)),
            };
        }
        let call = ir::Call {
            target: CallTarget::Builtin {
                name: up.to_string(),
                ty: None,
            },
            inputs: Vec::new(),
            outputs: Vec::new(),
            args: vals.into_iter().map(V::ir).collect(),
        };
        V::with(dint, span, ExprKind::Call(Box::new(call)))
    }
}

/// The bit-string type when `a` and `b` are an unsigned integer and a bit
/// string of the same size (UDINT and DWORD), else None.
/// An integer or bit-string type other than BOOL.
fn int_like(t: &Ty) -> bool {
    matches!(t, Ty::Elem(e) if e.is_int() || (e.is_bit() && *e != Elem::Bool))
}

fn same_size_bits(a: Elem, b: Elem) -> Option<Elem> {
    use Elem::*;
    let pair = |u: Elem, w: Elem| {
        matches!(
            (u, w),
            (Usint, Byte) | (Uint, Word) | (Udint, Dword) | (Ulint, Lword)
        )
    };
    if pair(a, b) {
        Some(b)
    } else if pair(b, a) {
        Some(a)
    } else {
        None
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
