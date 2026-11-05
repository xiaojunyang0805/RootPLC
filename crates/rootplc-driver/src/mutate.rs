//! `rootplc test --mutate`: mutation testing ([tests.mutation]).
//!
//! A mutant changes one token in a statement. Each mutant is checked and its
//! TEST blocks are run in-process; the score is killed ÷ viable mutants.

use std::path::PathBuf;

use rootplc_syntax::{TokenKind, lex};

use crate::{TestReport, check_sources_with, test_report};

/// Default cap on the number of mutants ([tests.mutation]).
pub const DEFAULT_LIMIT: usize = 500;

/// One single-token change.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Mutant {
    /// Index of the mutated file in the project sources.
    pub file: usize,
    /// Path of the mutated file.
    pub path: PathBuf,
    /// Byte offset of the token.
    pub offset: usize,
    /// 1-based line and column (in characters) of the token.
    pub line: usize,
    /// 1-based column.
    pub column: usize,
    /// Original token text.
    pub original: String,
    /// Replacement text (empty when the token is removed).
    pub replacement: String,
}

/// What happened to a mutant.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Outcome {
    /// The mutant does not compile; not counted.
    NotViable,
    /// At least one test failed.
    Killed,
    /// Every test still passed.
    Survived,
}

/// Result of a mutation run.
#[derive(Debug, Clone)]
pub struct MutationReport {
    /// The unchanged project's test run.
    pub baseline: TestReport,
    /// Why no mutant was run, if none was.
    pub error: Option<String>,
    /// Mutation candidates found before the limit was applied.
    pub candidates: usize,
    /// Each mutant that was run, with its outcome, in source order.
    pub mutants: Vec<(Mutant, Outcome)>,
}

impl MutationReport {
    /// Mutants that compiled.
    pub fn viable(&self) -> usize {
        self.mutants
            .iter()
            .filter(|(_, o)| *o != Outcome::NotViable)
            .count()
    }

    /// Mutants that a test caught.
    pub fn killed(&self) -> usize {
        self.mutants
            .iter()
            .filter(|(_, o)| *o == Outcome::Killed)
            .count()
    }

    /// Killed ÷ viable, or `None` when no mutant was viable.
    pub fn score(&self) -> Option<f64> {
        let v = self.viable();
        (v > 0).then(|| self.killed() as f64 / v as f64)
    }

    /// Surviving mutants, in source order.
    pub fn survivors(&self) -> impl Iterator<Item = &Mutant> {
        self.mutants
            .iter()
            .filter(|(_, o)| *o == Outcome::Survived)
            .map(|(m, _)| m)
    }
}

/// Every mutant of one source text, in source order ([tests.mutation]).
pub fn mutants_of(file: usize, path: &std::path::Path, source: &str) -> Vec<Mutant> {
    let tokens: Vec<_> = lex(source)
        .tokens
        .into_iter()
        .filter(|t| !t.kind.is_trivia() && t.kind != TokenKind::Pragma)
        .collect();
    let mut out = Vec::new();
    let mut in_test = false;
    let mut in_decl = false;
    let mut in_type = false;
    for (i, t) in tokens.iter().enumerate() {
        let text = t.text(source);
        let up = text.to_ascii_uppercase();
        let is_word = matches!(t.kind, TokenKind::Keyword | TokenKind::Ident);
        if is_word {
            let next_is_name = tokens
                .get(i + 1)
                .is_some_and(|n| n.kind == TokenKind::Ident);
            match up.as_str() {
                "TEST" if next_is_name => in_test = true,
                "END_TEST" => in_test = false,
                "END_VAR" => in_decl = false,
                "TYPE" => in_type = true,
                "END_TYPE" => in_type = false,
                u if u.starts_with("VAR") => in_decl = true,
                _ => {}
            }
        }
        if in_test || in_decl || in_type {
            continue;
        }
        let prev = i.checked_sub(1).map(|j| tokens[j]);
        let unary = !prev.is_some_and(|p| {
            matches!(
                p.kind,
                TokenKind::Ident
                    | TokenKind::Integer
                    | TokenKind::Real
                    | TokenKind::TypedLiteral
                    | TokenKind::Duration
                    | TokenKind::EnumLiteral
                    | TokenKind::DirectVariable
                    | TokenKind::RParen
                    | TokenKind::RBracket
                    | TokenKind::Caret
            )
        });
        let replacement: Option<String> = match t.kind {
            TokenKind::Lt => Some("<=".into()),
            TokenKind::Le => Some("<".into()),
            TokenKind::Gt => Some(">=".into()),
            TokenKind::Ge => Some(">".into()),
            TokenKind::Eq => Some("<>".into()),
            TokenKind::Neq => Some("=".into()),
            TokenKind::Plus if !unary => Some("-".into()),
            TokenKind::Minus if !unary => Some("+".into()),
            TokenKind::Keyword | TokenKind::Ident => match up.as_str() {
                "AND" => Some("OR".into()),
                "OR" => Some("AND".into()),
                "XOR" => Some("OR".into()),
                "TRUE" => Some("FALSE".into()),
                "FALSE" => Some("TRUE".into()),
                "NOT" => Some(String::new()),
                _ => None,
            },
            TokenKind::Integer => decimal_plus_one(text),
            TokenKind::Duration => doubled_duration(text),
            _ => None,
        };
        if let Some(r) = replacement {
            let (line, column) = rootplc_diag::line_col(source, t.span.start);
            out.push(Mutant {
                file,
                path: path.to_path_buf(),
                offset: t.span.start as usize,
                line,
                column,
                original: text.to_string(),
                replacement: r,
            });
        }
    }
    out
}

/// `n` → `n + 1` for a plain decimal literal (underscores allowed).
fn decimal_plus_one(text: &str) -> Option<String> {
    if !text.bytes().all(|b| b.is_ascii_digit() || b == b'_') {
        return None;
    }
    let digits: String = text.chars().filter(|c| *c != '_').collect();
    digits
        .parse::<u64>()
        .ok()?
        .checked_add(1)
        .map(|n| n.to_string())
}

/// `T#5s` → `T#10s` for a duration with one unit.
fn doubled_duration(text: &str) -> Option<String> {
    let (prefix, rest) = text.split_once('#')?;
    let digits: String = rest.chars().take_while(char::is_ascii_digit).collect();
    let unit = &rest[digits.len()..];
    if digits.is_empty() || unit.is_empty() || !unit.chars().all(|c| c.is_ascii_alphabetic()) {
        return None;
    }
    let n: u64 = digits.parse().ok()?;
    if n == 0 {
        return None; // [tests.mutation]: doubling T#0s cannot change it
    }
    Some(format!("{prefix}#{}{unit}", n.checked_mul(2)?))
}

/// Run mutation testing on a project ([tests.mutation]).
pub fn mutation_report(
    sources: Vec<(PathBuf, String)>,
    libraries: &[String],
    filter: Option<&str>,
    limit: usize,
) -> Result<MutationReport, String> {
    let baseline = test_report(check_sources_with(sources.clone(), libraries)?, filter);
    let mut report = MutationReport {
        baseline,
        error: None,
        candidates: 0,
        mutants: Vec::new(),
    };
    if !report.baseline.check.ok() {
        report.error = Some("the project does not compile; fix it before mutation testing".into());
        return Ok(report);
    }
    if report.baseline.outcomes.is_empty() {
        report.error = Some("no TEST blocks to run; write tests first".into());
        return Ok(report);
    }
    if !report.baseline.ok() {
        report.error = Some(
            "not every test passes on the unchanged code; mutation testing needs a green baseline"
                .into(),
        );
        return Ok(report);
    }
    let all: Vec<Mutant> = sources
        .iter()
        .enumerate()
        .flat_map(|(i, (p, s))| mutants_of(i, p, s))
        .collect();
    report.candidates = all.len();
    let chosen: Vec<Mutant> = all.into_iter().take(limit).collect();
    let workers = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(1)
        .clamp(1, 8);
    let chunk = chosen.len().div_ceil(workers).max(1);
    let outcomes: Vec<Outcome> = std::thread::scope(|scope| {
        let handles: Vec<_> = chosen
            .chunks(chunk)
            .map(|part| {
                let sources = &sources;
                scope.spawn(move || {
                    part.iter()
                        .map(|m| run_mutant(sources, libraries, filter, m))
                        .collect::<Vec<_>>()
                })
            })
            .collect();
        handles
            .into_iter()
            .flat_map(|h| h.join().unwrap_or_default())
            .collect()
    });
    report.mutants = chosen.into_iter().zip(outcomes).collect();
    Ok(report)
}

fn run_mutant(
    sources: &[(PathBuf, String)],
    libraries: &[String],
    filter: Option<&str>,
    m: &Mutant,
) -> Outcome {
    let mut mutated = sources.to_vec();
    let text = &mut mutated[m.file].1;
    text.replace_range(m.offset..m.offset + m.original.len(), &m.replacement);
    let Ok(check) = check_sources_with(mutated, libraries) else {
        return Outcome::NotViable;
    };
    if !check.ok() {
        return Outcome::NotViable;
    }
    if test_report(check, filter).ok() {
        Outcome::Survived
    } else {
        Outcome::Killed
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn names(src: &str) -> Vec<(String, String)> {
        mutants_of(0, std::path::Path::new("a.st"), src)
            .into_iter()
            .map(|m| (m.original, m.replacement))
            .collect()
    }

    #[test]
    fn statements_only() {
        let src = "PROGRAM P\nVAR x : INT := 5; t : TIME := T#1s; END_VAR\n\
                   IF x < 3 AND NOT FALSE THEN x := x + 1; END_IF;\nEND_PROGRAM\n\
                   TEST t1\nVAR p : P; END_VAR\nASSERT_TRUE(1 < 2);\nEND_TEST\n";
        assert_eq!(
            names(src),
            vec![
                ("<".into(), "<=".into()),
                ("3".into(), "4".into()),
                ("AND".into(), "OR".into()),
                ("NOT".into(), String::new()),
                ("FALSE".into(), "TRUE".into()),
                ("+".into(), "-".into()),
                ("1".into(), "2".into()),
            ]
        );
    }

    #[test]
    fn unary_minus_and_durations() {
        let src = "PROGRAM P\nVAR x : INT; END_VAR\nx := -1; x := (x - 2); tmr(PT := T#5s);\nEND_PROGRAM\n";
        let n = names(src);
        assert_eq!(
            n.iter().filter(|(o, _)| o == "-").count(),
            1,
            "unary minus is not mutated"
        );
        assert!(n.contains(&("T#5s".into(), "T#10s".into())));
        assert_eq!(doubled_duration("T#0s"), None);
        assert_eq!(doubled_duration("T#0ms"), None);
        assert!(n.contains(&("2".into(), "3".into())));
    }

    fn project(test: &str) -> Vec<(PathBuf, String)> {
        let code = "FUNCTION_BLOCK Latch\nVAR_INPUT start : BOOL; stop : BOOL; END_VAR\n\
                    VAR_OUTPUT running : BOOL; END_VAR\nrunning := (start OR running) AND NOT stop;\nEND_FUNCTION_BLOCK\n";
        vec![
            (PathBuf::from("latch.st"), code.to_string()),
            (PathBuf::from("latch_test.st"), test.to_string()),
        ]
    }

    #[test]
    fn strong_tests_kill_weak_tests_miss() {
        let strong = "TEST latches\nVAR l : Latch; END_VAR\nl(start := TRUE, stop := FALSE); ASSERT_TRUE(l.running);\n\
                      l(start := FALSE, stop := FALSE); ASSERT_TRUE(l.running);\n\
                      l(start := TRUE, stop := TRUE); ASSERT_FALSE(l.running);\nEND_TEST\n";
        let r = mutation_report(project(strong), &[], None, DEFAULT_LIMIT).expect("mutation run");
        assert!(r.error.is_none(), "{:?}", r.error);
        assert_eq!(
            r.score(),
            Some(1.0),
            "survivors: {:?}",
            r.survivors().collect::<Vec<_>>()
        );
        let weak = "TEST starts\nVAR l : Latch; END_VAR\nl(start := TRUE, stop := FALSE); ASSERT_TRUE(l.running);\nEND_TEST\n";
        let r = mutation_report(project(weak), &[], None, DEFAULT_LIMIT).expect("mutation run");
        assert!(r.score().expect("score") < 1.0);
        assert!(r.survivors().count() > 0);
    }

    #[test]
    fn needs_green_baseline_and_tests() {
        let failing = "TEST wrong\nVAR l : Latch; END_VAR\nl(start := TRUE, stop := FALSE); ASSERT_FALSE(l.running);\nEND_TEST\n";
        let r = mutation_report(project(failing), &[], None, DEFAULT_LIMIT).expect("mutation run");
        assert!(r.error.expect("error").contains("green baseline"));
        let none = mutation_report(project(""), &[], None, DEFAULT_LIMIT).expect("mutation run");
        assert!(none.error.expect("error").contains("no TEST blocks"));
    }

    #[test]
    fn limit_caps_mutants() {
        let strong = "TEST latches\nVAR l : Latch; END_VAR\nl(start := TRUE, stop := FALSE); ASSERT_TRUE(l.running);\nEND_TEST\n";
        let r = mutation_report(project(strong), &[], None, 2).expect("mutation run");
        assert_eq!(r.mutants.len(), 2);
        assert!(r.candidates > 2);
    }
}
