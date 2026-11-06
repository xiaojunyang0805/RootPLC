//! Dependency slices ([diff.slice], [tests.slice]): the files some roots
//! need, found from the names each file declares and uses.

use std::collections::{BTreeSet, HashMap};
use std::path::PathBuf;

use rootplc_syntax::TokenKind;

/// Names a file declares and names it uses ([diff.slice]), lower case.
fn names_of(src: &str) -> (BTreeSet<String>, BTreeSet<String>, bool) {
    let toks: Vec<_> = rootplc_syntax::lex(src)
        .tokens
        .into_iter()
        .filter(|t| {
            !matches!(
                t.kind,
                TokenKind::Whitespace
                    | TokenKind::LineComment
                    | TokenKind::BlockComment
                    | TokenKind::Pragma
            )
        })
        .collect();
    let word = |i: usize| toks[i].text(src).to_ascii_lowercase();
    let is_name = |i: usize| matches!(toks[i].kind, TokenKind::Ident | TokenKind::Keyword);
    const MODIFIERS: &[&str] = &[
        "public",
        "private",
        "protected",
        "internal",
        "abstract",
        "final",
    ];
    let mut declared = BTreeSet::new();
    let mut used = BTreeSet::new();
    let mut has_test = false;
    // TYPE … END_TYPE and VAR_GLOBAL … END_VAR: "name :" declares
    let mut section = false;
    for i in 0..toks.len() {
        let w = word(i);
        match toks[i].kind {
            TokenKind::Keyword => match w.as_str() {
                "function_block" | "function" | "program" | "interface" | "namespace" | "class" => {
                    let mut j = i + 1;
                    while j < toks.len() && MODIFIERS.contains(&word(j).as_str()) {
                        j += 1;
                    }
                    if j < toks.len() && is_name(j) {
                        declared.insert(word(j));
                    }
                }
                "type" | "var_global" => section = true,
                // a TEST block: TEST followed by its name (TcUnit calls TEST('x'))
                "test" => {
                    has_test |= toks.get(i + 1).is_some_and(|t| t.kind == TokenKind::Ident);
                }
                "end_type" | "end_var" => section = false,
                // reserved words some vendors accept as names
                _ => {
                    used.insert(w);
                }
            },
            TokenKind::Ident => {
                if section && toks.get(i + 1).is_some_and(|t| t.kind == TokenKind::Colon) {
                    declared.insert(w.clone());
                }
                used.insert(w);
            }
            TokenKind::EnumLiteral | TokenKind::TypedLiteral => {
                if let Some((ty, _)) = w.split_once('#') {
                    used.insert(ty.to_string());
                }
            }
            _ => {}
        }
    }
    (declared, used, has_test)
}

/// Keep the files marked in `start` and, transitively, every file that
/// declares a name a kept file uses: kept sources and left-out paths.
fn close(
    sources: Vec<(PathBuf, String)>,
    names: &[(BTreeSet<String>, BTreeSet<String>, bool)],
    start: Vec<usize>,
) -> (Vec<(PathBuf, String)>, Vec<PathBuf>) {
    let mut declares: HashMap<&str, Vec<usize>> = HashMap::new();
    for (i, (decl, _, _)) in names.iter().enumerate() {
        for d in decl {
            declares.entry(d.as_str()).or_default().push(i);
        }
    }
    let mut keep = vec![false; sources.len()];
    let mut work: Vec<usize> = Vec::new();
    for i in start {
        if !keep[i] {
            keep[i] = true;
            work.push(i);
        }
    }
    while let Some(i) = work.pop() {
        for u in &names[i].1 {
            for &j in declares.get(u.as_str()).into_iter().flatten() {
                if !keep[j] {
                    keep[j] = true;
                    work.push(j);
                }
            }
        }
    }
    let mut kept = Vec::new();
    let mut left = Vec::new();
    for (i, src) in sources.into_iter().enumerate() {
        if keep[i] {
            kept.push(src);
        } else {
            left.push(src.0);
        }
    }
    (kept, left)
}

/// The files the blocks `roots` need ([diff.slice]).
pub fn slice(
    sources: Vec<(PathBuf, String)>,
    roots: &[&str],
) -> (Vec<(PathBuf, String)>, Vec<PathBuf>) {
    let names: Vec<_> = sources.iter().map(|(_, s)| names_of(s)).collect();
    let roots: Vec<String> = roots.iter().map(|r| r.to_ascii_lowercase()).collect();
    let start = names
        .iter()
        .enumerate()
        .filter(|(_, (decl, _, _))| roots.iter().any(|r| decl.contains(r)))
        .map(|(i, _)| i)
        .collect();
    close(sources, &names, start)
}

/// The files the TEST blocks need ([tests.slice]).
pub fn slice_tests(sources: Vec<(PathBuf, String)>) -> (Vec<(PathBuf, String)>, Vec<PathBuf>) {
    let names: Vec<_> = sources.iter().map(|(_, s)| names_of(s)).collect();
    let start = names
        .iter()
        .enumerate()
        .filter(|(_, n)| n.2)
        .map(|(i, _)| i)
        .collect();
    close(sources, &names, start)
}
