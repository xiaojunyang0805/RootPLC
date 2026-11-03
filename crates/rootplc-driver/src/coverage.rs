//! `rootplc coverage`: how much of a code base RootPLC can take today, unit
//! by unit. Each file is a unit and gets one status:
//!
//! - `portable`: checks without errors; tests and the VM can run it.
//! - `dialect`: has errors and uses constructs RootPLC does not support yet
//!   (vendor extensions such as unions, VAR_STAT, vendor pragmas). The
//!   constructs are listed with their lines, so the cause is visible.
//!   Implicit narrowing conversions (RP0103), which vendor compilers accept
//!   and strict IEC 61131-3 does not, count as a dialect trait here.
//! - `dependent`: its only errors are unknown names declared in units that
//!   do not compile; it moves with them.
//! - `blocked`: has errors without any such construct. Either the code is
//!   wrong or RootPLC has a gap; the diagnostics say which.
//!
//! Construct detection runs on lexer tokens, never on raw text, so comments
//! and strings cannot cause false hits. `corpus/corpus.py` still counts
//! features with its own regular expressions; moving it onto this report
//! is planned.

use std::path::PathBuf;

use rootplc_diag::{Severity, line_col};
use rootplc_syntax::{Token, TokenKind};

/// Status of one unit.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    /// No errors.
    Portable,
    /// Errors, explained by unsupported constructs.
    Dialect,
    /// Compiles except for names declared in units that do not compile.
    Dependent,
    /// Errors without an unsupported construct.
    Blocked,
}

impl Status {
    /// Name in reports.
    pub fn name(self) -> &'static str {
        match self {
            Status::Portable => "portable",
            Status::Dialect => "dialect",
            Status::Dependent => "dependent",
            Status::Blocked => "blocked",
        }
    }
}

/// An unsupported construct found in a unit.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Construct {
    /// Display name, e.g. `POINTER TO`.
    pub name: &'static str,
    /// Defined by IEC 61131-3 ed.3 (true) or a vendor extension (false).
    pub iec: bool,
    /// 1-based line of the first occurrence.
    pub line: usize,
    /// Occurrences in the unit.
    pub count: usize,
}

/// Coverage of one file.
#[derive(Debug, Clone)]
pub struct Unit {
    /// Path as given or found.
    pub path: PathBuf,
    /// Status.
    pub status: Status,
    /// Error count from `check`.
    pub errors: usize,
    /// Distinct error codes, sorted.
    pub codes: Vec<String>,
    /// Unsupported constructs, in order of first appearance.
    pub constructs: Vec<Construct>,
    /// Non-compiling units whose names this unit uses (unknown-name errors).
    pub blocked_by: Vec<PathBuf>,
}

/// Result of [`coverage`].
#[derive(Debug, Clone)]
pub struct CoverageReport {
    /// One entry per file, in path order.
    pub units: Vec<Unit>,
}

impl CoverageReport {
    /// Units with a status.
    pub fn count(&self, s: Status) -> usize {
        self.units.iter().filter(|u| u.status == s).count()
    }
}

/// (name, IEC ed.3?, matcher over significant tokens at index i).
type Rule = (&'static str, bool, fn(&Ctx, usize) -> bool);

struct Ctx<'a> {
    src: &'a str,
    toks: Vec<Token>,
}

impl Ctx<'_> {
    fn word(&self, i: usize) -> String {
        self.toks
            .get(i)
            .filter(|t| matches!(t.kind, TokenKind::Ident | TokenKind::Keyword))
            .map(|t| t.text(self.src).to_ascii_uppercase())
            .unwrap_or_default()
    }

    fn is(&self, i: usize, w: &str) -> bool {
        self.word(i) == w
    }

    fn kind(&self, i: usize) -> Option<TokenKind> {
        self.toks.get(i).map(|t| t.kind)
    }
}

const RULES: &[Rule] = &[
    ("UNION", false, |c, i| c.is(i, "UNION")),
    ("VAR_STAT", false, |c, i| c.is(i, "VAR_STAT")),
    ("SIZEOF", false, |c, i| {
        c.is(i, "SIZEOF") && c.kind(i + 1) == Some(TokenKind::LParen)
    }),
    ("__ system calls", false, |c, i| {
        let w = c.word(i);
        w.starts_with("__") && w != "__ISVALIDREF" && c.kind(i + 1) == Some(TokenKind::LParen)
    }),
    ("vendor pragmas {..}", false, |c, i| {
        let t = c.toks[i];
        if t.kind != TokenKind::Pragma {
            return false;
        }
        let word: String = t
            .text(c.src)
            .trim_start_matches('{')
            .trim_start()
            .chars()
            .take_while(|ch| ch.is_alphanumeric() || *ch == '_')
            .collect();
        !word.is_empty() && !rootplc_syntax::token::is_known_pragma(&word)
    }),
];

/// Unsupported constructs in one source text.
pub fn constructs(source: &str) -> Vec<Construct> {
    let ctx = Ctx {
        src: source,
        toks: rootplc_syntax::lex(source)
            .tokens
            .into_iter()
            .filter(|t| !t.kind.is_trivia())
            .collect(),
    };
    let mut out: Vec<Construct> = Vec::new();
    for i in 0..ctx.toks.len() {
        for &(name, iec, matches) in RULES {
            if !matches(&ctx, i) {
                continue;
            }
            match out.iter_mut().find(|c| c.name == name) {
                Some(c) => c.count += 1,
                None => out.push(Construct {
                    name,
                    iec,
                    line: line_col(source, ctx.toks[i].span.start).0,
                    count: 1,
                }),
            }
        }
    }
    out
}

/// `rootplc coverage`: check the files as one project, then classify each.
pub fn coverage(paths: &[PathBuf]) -> Result<CoverageReport, String> {
    Ok(coverage_sources(crate::read_sources(paths)?))
}

/// Names a unit declares: POUs, types, and global variables.
fn declared_names(source: &str) -> Vec<String> {
    let ctx = Ctx {
        src: source,
        toks: rootplc_syntax::lex(source)
            .tokens
            .into_iter()
            .filter(|t| !t.kind.is_trivia())
            .collect(),
    };
    let mut out = Vec::new();
    let mut in_globals = false;
    for i in 0..ctx.toks.len() {
        let w = ctx.word(i);
        match w.as_str() {
            "PROGRAM" | "FUNCTION_BLOCK" | "FUNCTION" | "INTERFACE" | "TYPE" => {
                out.push(ctx.word(i + 1));
            }
            "VAR_GLOBAL" => in_globals = true,
            "END_VAR" => in_globals = false,
            _ if in_globals
                && ctx.kind(i) == Some(TokenKind::Ident)
                && matches!(ctx.kind(i + 1), Some(TokenKind::Colon | TokenKind::Comma)) =>
            {
                out.push(w);
            }
            _ => {}
        }
    }
    out.retain(|n| !n.is_empty());
    out
}

/// The first 'quoted' name in a message, upper-cased.
fn quoted(message: &str) -> Option<String> {
    let rest = message.split_once('\'')?.1;
    Some(rest.split_once('\'')?.0.to_ascii_uppercase())
}

/// [`coverage`] on sources held in memory.
pub fn coverage_sources(sources: Vec<(PathBuf, String)>) -> CoverageReport {
    classify(crate::check_sources(sources))
}

/// [`coverage_sources`] with compatibility libraries ([stdlib.compat]);
/// library files are never units.
pub fn coverage_sources_with(
    sources: Vec<(PathBuf, String)>,
    libraries: &[String],
) -> Result<CoverageReport, String> {
    Ok(classify(crate::check_sources_with(sources, libraries)?))
}

fn classify(check: crate::CheckReport) -> CoverageReport {
    use rootplc_diag::codes::{IMPLICIT_CONVERSION, UNKNOWN_NAME, UNKNOWN_TYPE};
    // (name, unit) for every name declared by a unit that does not compile
    let mut broken_decl: Vec<(String, usize)> = Vec::new();
    for (i, f) in check.files.iter().enumerate() {
        if f.diagnostics.iter().any(|d| d.severity == Severity::Error) {
            broken_decl.extend(declared_names(&f.source).into_iter().map(|n| (n, i)));
        }
    }
    let paths: Vec<PathBuf> = check.files.iter().map(|f| f.path.clone()).collect();
    let units = check
        .files
        .into_iter()
        .enumerate()
        .filter(|(_, f)| !f.library)
        .map(|(idx, f)| {
            let errors: Vec<_> = f
                .diagnostics
                .iter()
                .filter(|d| d.severity == Severity::Error)
                .collect();
            let mut codes: Vec<String> = errors
                .iter()
                .map(|d| format!("RP{:04}", d.code.0))
                .collect();
            codes.sort();
            codes.dedup();
            let mut constructs = constructs(&f.source);
            let conversions: Vec<_> = errors
                .iter()
                .filter(|d| d.code == IMPLICIT_CONVERSION)
                .collect();
            if let Some(first) = conversions.first() {
                constructs.push(Construct {
                    name: "implicit narrowing conversion",
                    iec: false,
                    line: line_col(&f.source, first.span.start).0,
                    count: conversions.len(),
                });
            }
            let mut blocked_by: Vec<PathBuf> = Vec::new();
            let mut own_errors = 0;
            for d in &errors {
                let dep = (d.code == UNKNOWN_NAME || d.code == UNKNOWN_TYPE)
                    .then(|| quoted(&d.message))
                    .flatten()
                    .and_then(|n| broken_decl.iter().find(|(b, u)| *b == n && *u != idx))
                    .map(|&(_, u)| paths[u].clone());
                match dep {
                    Some(p) => {
                        if !blocked_by.contains(&p) {
                            blocked_by.push(p);
                        }
                    }
                    None if d.code != IMPLICIT_CONVERSION => own_errors += 1,
                    None => {}
                }
            }
            let status = if errors.is_empty() {
                Status::Portable
            } else if !constructs.is_empty() {
                Status::Dialect
            } else if own_errors == 0 {
                Status::Dependent
            } else {
                Status::Blocked
            };
            Unit {
                path: f.path,
                status,
                errors: errors.len(),
                codes,
                constructs,
                blocked_by,
            }
        })
        .collect();
    CoverageReport { units }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn names(src: &str) -> Vec<&'static str> {
        constructs(src).into_iter().map(|c| c.name).collect()
    }

    #[test]
    fn detects_constructs_on_tokens_only() {
        let src = "FUNCTION_BLOCK FB_A EXTENDS FB_Base\nVAR n : INT; u : UNION a : INT; END_UNION; END_VAR\n\
                   n := SIZEOF(n); (* SIZEOF(n) in a comment *) s := 'UNION';\nTHIS^.x := __NEW(INT);\nVAR_STAT\n{region main}\n{attribute 'hide'}\nEND_FUNCTION_BLOCK";
        let found = constructs(src);
        let n: Vec<_> = found.iter().map(|c| c.name).collect();
        assert_eq!(
            n,
            [
                "UNION",
                "SIZEOF",
                "__ system calls",
                "VAR_STAT",
                "vendor pragmas {..}"
            ]
        );
        assert_eq!(found[1].line, 3);
        assert_eq!(found[1].count, 1, "the comment must not count");
        assert_eq!(found[0].count, 1, "the string must not count");
        assert!(found.iter().all(|c| !c.iec));
    }

    #[test]
    fn identifiers_are_not_constructs() {
        assert!(names("PROGRAM p VAR union_count : INT; END_VAR END_PROGRAM").is_empty());
    }

    #[test]
    fn classifies_units() {
        let r = coverage_sources(vec![
            (
                PathBuf::from("a.st"),
                "PROGRAM a VAR x : INT; END_VAR x := x + 1; END_PROGRAM".into(),
            ),
            (
                PathBuf::from("b.st"),
                "PROGRAM b VAR u : UNION a : INT; END_UNION; END_VAR END_PROGRAM".into(),
            ),
            (
                PathBuf::from("c.st"),
                "PROGRAM c VAR x : INT; END_VAR x := y; END_PROGRAM".into(),
            ),
        ]);
        let s: Vec<_> = r.units.iter().map(|u| u.status).collect();
        assert_eq!(s, [Status::Portable, Status::Dialect, Status::Blocked]);
        assert_eq!(r.units[2].codes, ["RP0203"]);
        assert_eq!(r.count(Status::Portable), 1);
    }

    #[test]
    fn cascades_and_conversions() {
        let r = coverage_sources(vec![
            (
                PathBuf::from("lib.st"),
                "FUNCTION_BLOCK FB_Lib\nVAR u : UNION a : INT; END_UNION; END_VAR\nEND_FUNCTION_BLOCK"
                    .into(),
            ),
            (
                PathBuf::from("user.st"),
                "PROGRAM user VAR f : FB_Lib; END_VAR f(); END_PROGRAM".into(),
            ),
            (
                PathBuf::from("conv.st"),
                "PROGRAM conv VAR s : SINT; i : INT; END_VAR s := i; END_PROGRAM".into(),
            ),
        ]);
        let s: Vec<_> = r.units.iter().map(|u| u.status).collect();
        assert_eq!(s, [Status::Dialect, Status::Dependent, Status::Dialect]);
        assert_eq!(r.units[1].blocked_by, [PathBuf::from("lib.st")]);
        assert_eq!(
            r.units[2].constructs[0].name,
            "implicit narrowing conversion"
        );
    }
}
