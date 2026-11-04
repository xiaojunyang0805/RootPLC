//! Name resolution, type checking and the typed IR consumed by every back end.
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`. Implemented: `check` v0 (name
//! resolution and type checking per spec/02-types.md, spec/03-variables.md,
//! spec/07-test-blocks.md and spec/08-stdlib.md) and the typed IR (`ir`).

mod check;
pub mod ir;
pub mod literal;
pub mod types;

pub use types::{Elem, Ty};

use rootplc_diag::{Diagnostic, Severity};
use rootplc_syntax::Parse;

/// Semantic diagnostics for a parsed file. Callers should run this only when
/// the file lexes and parses without errors.
pub fn check(parse: &Parse, source: &str) -> Vec<Diagnostic> {
    check_project(&[(parse, source)]).pop().unwrap_or_default()
}

/// Check the files of one project together: names declared in one file are
/// visible in the others. Returns the diagnostics of each file, in order.
pub fn check_project(files: &[(&Parse, &str)]) -> Vec<Vec<Diagnostic>> {
    analyze(files).diagnostics
}

/// Result of [`analyze`].
#[derive(Debug, Clone)]
pub struct Analysis {
    /// Checker diagnostics of each file, in order.
    pub diagnostics: Vec<Vec<Diagnostic>>,
    /// The typed IR. Execute it only if no diagnostic is an error.
    pub program: ir::Program,
}

impl Analysis {
    /// True if no diagnostic is an error.
    pub fn ok(&self) -> bool {
        !self
            .diagnostics
            .iter()
            .flatten()
            .any(|d| d.severity == Severity::Error)
    }
}

/// Settings for [`analyze_with`] that come from outside the source.
#[derive(Debug, Clone, Default)]
pub struct Options {
    /// Functions declared by an active compatibility library but not
    /// implemented by RootPLC: calls are warning RP0120, running one is the
    /// fault UNSUPPORTED ([stdlib.compat]).
    pub declare_only: Vec<String>,
    /// Names that may qualify a declaration in expressions, `Tc2_System.PI`:
    /// the active compatibility libraries ([stdlib.compat]).
    pub qualifiers: Vec<String>,
    /// Compiler operators enabled by active libraries, e.g. `SIZEOF`
    /// ([stdlib.compat.sizeof]).
    pub intrinsics: Vec<String>,
}

/// Check a project and produce its typed IR.
pub fn analyze(files: &[(&Parse, &str)]) -> Analysis {
    analyze_with(files, &Options::default())
}

/// [`analyze`] with options, e.g. active compatibility libraries.
pub fn analyze_with(files: &[(&Parse, &str)], opts: &Options) -> Analysis {
    let mut c = check::Checker::new(
        files
            .iter()
            .map(|(p, s)| (*s, p.tokens.as_slice()))
            .collect(),
    );
    c.set_options(opts);
    let roots: Vec<&rootplc_syntax::Node> = files.iter().map(|(p, _)| &p.tree).collect();
    c.run(&roots);
    let mut diagnostics = vec![Vec::new(); files.len()];
    for (f, d) in std::mem::take(&mut c.diags) {
        diagnostics[f].push(d);
    }
    Analysis {
        diagnostics,
        program: c.into_program(),
    }
}

/// Result of [`check_source`].
#[derive(Debug, Clone)]
pub struct CheckResult {
    /// Lexer, parser and checker diagnostics, in that order.
    pub diagnostics: Vec<Diagnostic>,
}

impl CheckResult {
    /// True if no diagnostic is an error.
    pub fn ok(&self) -> bool {
        !self
            .diagnostics
            .iter()
            .any(|d| d.severity == Severity::Error)
    }
}

/// Lex, parse and check one source file. The checker runs only when lexing
/// and parsing produced no errors, so syntax errors do not cascade.
pub fn check_source(source: &str) -> CheckResult {
    let p = rootplc_syntax::parse(source);
    let mut diagnostics = p.lex_diagnostics.clone();
    diagnostics.extend(p.diagnostics.iter().cloned());
    let syntax_ok = !diagnostics.iter().any(|d| d.severity == Severity::Error);
    if syntax_ok {
        diagnostics.extend(check(&p, source));
    }
    CheckResult { diagnostics }
}

#[cfg(test)]
mod tests {
    use super::check_source;

    fn codes(src: &str) -> Vec<u16> {
        check_source(src)
            .diagnostics
            .iter()
            .map(|d| d.code.0)
            .collect()
    }

    #[test]
    fn clean_program() {
        let src = "PROGRAM p VAR a : INT; b : BOOL; t : TON; END_VAR
a := a + 1; b := a > 3 AND t.Q; t(IN := b, PT := T#1s); END_PROGRAM";
        assert_eq!(codes(src), Vec::<u16>::new());
    }

    #[test]
    fn unknown_function_and_member() {
        assert_eq!(
            codes("PROGRAM p VAR a : INT; END_VAR a := Foo(1); END_PROGRAM"),
            [203]
        );
        assert_eq!(
            codes(
                "TYPE S : STRUCT x : INT; END_STRUCT; END_TYPE PROGRAM p VAR s : S; END_VAR s.y := 1; END_PROGRAM"
            ),
            [203]
        );
    }

    #[test]
    fn condition_must_be_bool() {
        assert_eq!(
            codes("PROGRAM p VAR i : INT; END_VAR IF i THEN i := 0; END_IF; END_PROGRAM"),
            [103]
        );
    }

    #[test]
    fn subrange_literal_in_statement() {
        let src = "TYPE Pct : INT (0..100); END_TYPE PROGRAM p VAR x : Pct; END_VAR x := 101; END_PROGRAM";
        assert_eq!(codes(src), [105]);
    }

    #[test]
    fn hint_names_conversion() {
        let r = check_source("PROGRAM p VAR s : SINT; i : INT; END_VAR s := i; END_PROGRAM");
        assert_eq!(
            r.diagnostics[0].hint.as_deref(),
            Some("use INT_TO_SINT(...) to convert explicitly")
        );
    }

    #[test]
    fn syntax_errors_skip_checking() {
        // `y` is unknown, but the missing ';' stops the checker from running.
        assert_eq!(
            codes("PROGRAM p VAR x : INT; END_VAR x := y END_PROGRAM"),
            [301]
        );
    }

    #[test]
    fn duplicate_global_names() {
        let src = "TYPE M : INT; END_TYPE PROGRAM m END_PROGRAM";
        assert_eq!(codes(src), [204]);
        // A user POU may replace a standard block.
        let src = "FUNCTION_BLOCK TON VAR_INPUT IN : BOOL; END_VAR END_FUNCTION_BLOCK";
        assert_eq!(codes(src), Vec::<u16>::new());
    }

    #[test]
    fn names_across_files() {
        let a = "FUNCTION_BLOCK FB VAR_OUTPUT q : BOOL; END_VAR END_FUNCTION_BLOCK";
        let b = "PROGRAM p VAR f : FB; x : BOOL; END_VAR f(); x := f.q; x := f.r; END_PROGRAM";
        let (pa, pb) = (rootplc_syntax::parse(a), rootplc_syntax::parse(b));
        let out = super::check_project(&[(&pa, a), (&pb, b)]);
        assert!(out[0].is_empty());
        assert_eq!(out[1].iter().map(|d| d.code.0).collect::<Vec<_>>(), [203]);
    }
}
