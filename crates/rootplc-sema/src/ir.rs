//! Typed intermediate representation, emitted by the checker.
//!
//! Every name is resolved: variables are slot indices in their POU frame,
//! members are field indices, calls name their target. Every expression
//! carries its type. Constants are folded. Back ends (the VM today; C and
//! CBMC later) consume only this, never the syntax tree.

use rootplc_diag::Span;

use crate::types::{Elem, Ty};

/// Kind of a program organisation unit.
#[allow(missing_docs)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PouKind {
    Program,
    Function,
    FunctionBlock,
    Test,
    /// A method of a function block or program, [pous.oop.method].
    Method,
    /// An interface: method signatures only, [pous.oop.interface].
    Interface,
}

/// Variable section.
#[allow(missing_docs)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Section {
    Input,
    Output,
    InOut,
    Local,
    /// The result variable of a function (always the last slot).
    Result,
}

/// A checked project.
#[derive(Debug, Clone, Default)]
pub struct Program {
    /// Every declared type and POU; `Ty::Named(i)` indexes this list.
    pub defs: Vec<Def>,
    /// The definition holding the global variables (instantiated once per
    /// VM), if the project declares any, [config.global-list].
    pub globals: Option<usize>,
}

impl Program {
    /// Look up a type or POU by name (case-insensitive).
    pub fn find(&self, name: &str) -> Option<usize> {
        self.defs
            .iter()
            .rposition(|d| d.name.eq_ignore_ascii_case(name))
    }

    /// The POU with index `id`, if it is one.
    pub fn pou(&self, id: usize) -> Option<&Pou> {
        match &self.defs.get(id)?.kind {
            DefKind::Pou(p) => Some(p),
            _ => None,
        }
    }

    /// Indices of all TEST blocks, in declaration order.
    pub fn tests(&self) -> Vec<usize> {
        (0..self.defs.len())
            .filter(|&i| matches!(self.pou(i), Some(p) if p.kind == PouKind::Test))
            .collect()
    }
}

/// A declared type or POU.
#[derive(Debug, Clone)]
pub struct Def {
    /// Name as declared.
    pub name: String,
    /// Index of the source file that declares it.
    pub file: usize,
    /// What it is.
    pub kind: DefKind,
}

/// What a definition is.
#[derive(Debug, Clone)]
pub enum DefKind {
    /// Could not be resolved (an error was reported).
    Unresolved,
    /// Alias of another type.
    Alias(Ty),
    /// Structure with its members.
    Struct(Vec<Var>),
    /// Enumeration values in order.
    Enum(Vec<(String, i128)>),
    /// Subrange of an integer type.
    Subrange {
        /// Base type.
        base: Elem,
        /// Lower bound.
        lo: i128,
        /// Upper bound.
        hi: i128,
    },
    /// Program, function, function block or test.
    Pou(Pou),
}

/// A variable, structure member or POU parameter.
#[derive(Debug, Clone)]
pub struct Var {
    /// Name as declared.
    pub name: String,
    /// Type.
    pub ty: Ty,
    /// Section.
    pub section: Section,
    /// Initial value; `None` means the default of the type.
    pub init: Option<Init>,
}

/// A program organisation unit.
#[derive(Debug, Clone)]
pub struct Pou {
    /// Kind.
    pub kind: PouKind,
    /// Frame slots: declared variables, then the result for a function.
    pub vars: Vec<Var>,
    /// Result type of a function.
    pub ret: Option<Ty>,
    /// Body.
    pub body: Vec<Stmt>,
    /// A standard block implemented natively by the back end.
    pub builtin: bool,
    /// For a method: the function block or program it belongs to.
    pub owner: Option<usize>,
    /// Declared by a compatibility library but not implemented: running it
    /// is the fault UNSUPPORTED, [stdlib.compat].
    pub declare_only: bool,
    /// The function block this one extends, [pous.oop.extends].
    pub base: Option<usize>,
    /// Methods callable on an instance, inherited ones included, with
    /// overrides applied: (name, method definition), [pous.oop.override].
    pub methods: Vec<(String, usize)>,
}

/// Initial value.
#[derive(Debug, Clone)]
pub enum Init {
    /// A constant expression.
    Expr(Expr),
    /// Array elements in order.
    Array(Vec<Init>),
    /// Structure members by index.
    Struct(Vec<(usize, Init)>),
}

/// A typed expression.
#[derive(Debug, Clone)]
pub struct Expr {
    /// Type of the value.
    pub ty: Ty,
    /// What it computes.
    pub kind: ExprKind,
    /// Source location.
    pub span: Span,
}

/// Expression forms.
#[derive(Debug, Clone)]
pub enum ExprKind {
    /// Only after an error; never executed.
    Invalid,
    /// Folded constant.
    Const(Const),
    /// Slot of the current frame.
    Var(usize),
    /// The function-block or program instance a method or body runs on
    /// (its type is that block), [pous.oop.this].
    This,
    /// A reference to the instance at a place, as a value of an interface
    /// type; `usize` is the instance's block, [pous.oop.interface-ref].
    ToItf(Box<Expr>, usize),
    /// Global variable `slot`, [config.global-list].
    Global(usize),
    /// Member `index` of a structure or instance.
    Member(Box<Expr>, usize),
    /// Bit `n` of an integer or bit string.
    Bit(Box<Expr>, u32),
    /// Array element.
    Index(Box<Expr>, Vec<Expr>),
    /// `r^`.
    Deref(Box<Expr>),
    /// `REF(x)`.
    Ref(Box<Expr>),
    /// Unary operator.
    Unary(UnOp, Box<Expr>),
    /// Binary operator; operands are converted to `opty` first.
    Binary {
        /// Operator.
        op: BinOp,
        /// Common type of the operands.
        opty: Ty,
        /// Left operand.
        l: Box<Expr>,
        /// Right operand.
        r: Box<Expr>,
    },
    /// Call.
    Call(Box<Call>),
    /// `NULL`.
    Null,
}

/// Constant value. Durations, dates and characters are integers in their
/// representation unit ([types.elementary]).
#[derive(Debug, Clone, PartialEq)]
pub enum Const {
    /// BOOL.
    Bool(bool),
    /// Integers, bit strings, enumerations, durations, dates, characters.
    Int(i128),
    /// REAL and LREAL.
    Real(f64),
    /// STRING and WSTRING, decoded.
    Str(String),
}

/// Unary operators.
#[allow(missing_docs)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UnOp {
    Neg,
    Not,
}

/// Binary operators.
#[allow(missing_docs)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BinOp {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    Pow,
    Eq,
    Ne,
    Lt,
    Gt,
    Le,
    Ge,
    And,
    Or,
    Xor,
    AndThen,
    OrElse,
}

/// A call.
#[derive(Debug, Clone)]
pub struct Call {
    /// What is called.
    pub target: CallTarget,
    /// Inputs by parameter slot (user POUs and instances).
    pub inputs: Vec<(usize, Expr)>,
    /// Outputs bound with `=>`: parameter slot and the target place.
    pub outputs: Vec<(usize, Expr)>,
    /// Positional arguments (standard functions).
    pub args: Vec<Expr>,
}

/// Call targets.
#[derive(Debug, Clone)]
pub enum CallTarget {
    /// An instance of a function block or program (definition index).
    Instance(Expr, usize),
    /// A user function (definition index).
    Function(usize),
    /// A method call on the instance `inst` of function block `fb`. With
    /// `dispatch`, the method is looked up by `name` in the instance's own
    /// method table (overrides apply); otherwise `method` runs (SUPER^.M()).
    Method {
        /// Place of the instance.
        inst: Expr,
        /// Static type of the instance.
        fb: usize,
        /// Method found at compile time.
        method: usize,
        /// Method name, for dispatch.
        name: String,
        /// Look the method up in the instance's table at run time.
        dispatch: bool,
    },
    /// A standard function, by upper-case name. `ty` is the parameter type of
    /// a conversion (`INT` in `INT_TO_SINT`) or the common type of the
    /// arguments of an overloaded function.
    Builtin {
        /// Upper-case name.
        name: String,
        /// Parameter or common type.
        ty: Option<Ty>,
    },
}

/// Statements.
#[derive(Debug, Clone)]
pub enum Stmt {
    /// `place := value`; the value is converted to the place's type.
    Assign(Expr, Expr),
    /// A call evaluated for its effect.
    Eval(Expr),
    /// Condition/branch pairs, then the ELSE branch.
    If(Vec<(Expr, Vec<Stmt>)>, Vec<Stmt>),
    /// CASE with constant label ranges.
    Case {
        /// Selector.
        sel: Expr,
        /// Branches.
        arms: Vec<CaseArm>,
        /// ELSE branch.
        default: Vec<Stmt>,
    },
    /// FOR loop.
    For(Box<ForLoop>),
    /// WHILE loop.
    While(Expr, Vec<Stmt>),
    /// REPEAT … UNTIL.
    Repeat(Vec<Stmt>, Expr),
    /// EXIT.
    Exit,
    /// CONTINUE.
    Continue,
    /// RETURN.
    Return,
}

/// One CASE branch.
#[derive(Debug, Clone)]
pub struct CaseArm {
    /// Constant label ranges (`lo..hi`; a single label has `lo == hi`).
    pub labels: Vec<(i128, i128)>,
    /// Statements.
    pub body: Vec<Stmt>,
}

/// A FOR loop.
#[derive(Debug, Clone)]
pub struct ForLoop {
    /// Control variable (a place).
    pub var: Expr,
    /// Start value.
    pub from: Expr,
    /// End value.
    pub to: Expr,
    /// Step, default 1.
    pub by: Option<Expr>,
    /// Body.
    pub body: Vec<Stmt>,
}
