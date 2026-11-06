//! Editor features behind `rootplc lsp` (spec/19-lsp.md): project
//! diagnostics with 0-based ranges, an outline from the tokens (works on
//! text that does not compile), go-to-definition and hover. Positions are
//! 0-based lines and characters (code points).

use std::path::{Path, PathBuf};

use rootplc_diag::line_col;
use rootplc_syntax::lexer::lex;
use rootplc_syntax::token::TokenKind;

/// A diagnostic as an editor shows it ([lsp.diagnostics]).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct IdeDiag {
    /// Start line (0-based).
    pub line: usize,
    /// Start character.
    pub col: usize,
    /// End line.
    pub end_line: usize,
    /// End character.
    pub end_col: usize,
    /// 1 error, 2 warning, 3 information.
    pub severity: u8,
    /// `RPnnnn`.
    pub code: String,
    /// Message, with the hint on a second line when there is one.
    pub message: String,
}

/// Check the project and return the diagnostics of every project file
/// (files without diagnostics included, with an empty list).
pub fn project_diagnostics(
    sources: Vec<(PathBuf, String)>,
    libraries: &[String],
) -> Result<Vec<(PathBuf, Vec<IdeDiag>)>, String> {
    let report = crate::check_sources_with(sources, libraries)?;
    let mut out = Vec::new();
    for f in report.files.iter().filter(|f| !f.library) {
        let mut ds = Vec::new();
        for d in &f.diagnostics {
            let (l, c) = line_col(&f.source, d.span.start);
            let (el, ec) = line_col(&f.source, d.span.end);
            let severity = match d.severity.as_str() {
                "error" => 1,
                "warning" => 2,
                _ => 3,
            };
            let message = match &d.hint {
                Some(h) => format!("{}\n{h}", d.message),
                None => d.message.clone(),
            };
            ds.push(IdeDiag {
                line: l.saturating_sub(1),
                col: c.saturating_sub(1),
                end_line: el.saturating_sub(1),
                end_col: ec.saturating_sub(1),
                severity,
                code: d.code.to_string(),
                message,
            });
        }
        out.push((f.path.clone(), ds));
    }
    Ok(out)
}

/// Kind of a declaration in the outline (LSP SymbolKind numbers).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SymKind {
    /// PROGRAM, CONFIGURATION (Module 2).
    Module,
    /// FUNCTION_BLOCK (Class 5).
    Class,
    /// METHOD (Method 6).
    Method,
    /// INTERFACE (Interface 11).
    Interface,
    /// FUNCTION (Function 12).
    Function,
    /// A variable (Variable 13).
    Variable,
    /// A structure member (Field 8).
    Field,
    /// A type (Struct 23).
    Type,
    /// TEST (Event 24).
    Test,
    /// A global variable list (Namespace 3).
    Globals,
}

impl SymKind {
    /// The LSP `SymbolKind` number.
    pub fn lsp(self) -> u8 {
        match self {
            SymKind::Module => 2,
            SymKind::Globals => 3,
            SymKind::Class => 5,
            SymKind::Method => 6,
            SymKind::Field => 8,
            SymKind::Interface => 11,
            SymKind::Function => 12,
            SymKind::Variable => 13,
            SymKind::Type => 23,
            SymKind::Test => 24,
        }
    }
}

/// A position range, 0-based.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct Range {
    /// Start line.
    pub line: usize,
    /// Start character.
    pub col: usize,
    /// End line.
    pub end_line: usize,
    /// End character.
    pub end_col: usize,
}

impl Range {
    fn contains(&self, line: usize, col: usize) -> bool {
        (line, col) >= (self.line, self.col) && (line, col) <= (self.end_line, self.end_col)
    }
}

/// One declaration ([lsp.symbols]).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Symbol {
    /// Declared name.
    pub name: String,
    /// Kind.
    pub kind: SymKind,
    /// The whole declaration.
    pub range: Range,
    /// The name.
    pub selection: Range,
    /// Type or other detail (`INT`, `FUNCTION_BLOCK`).
    pub detail: String,
    /// Members: variables, methods, structure members.
    pub children: Vec<Symbol>,
}

struct Tok {
    kind: TokenKind,
    text: String,
    up: String,
    start: u32,
    end: u32,
}

fn pos(source: &str, offset: u32) -> (usize, usize) {
    let (l, c) = line_col(source, offset);
    (l.saturating_sub(1), c.saturating_sub(1))
}

fn range(source: &str, a: u32, b: u32) -> Range {
    let (line, col) = pos(source, a);
    let (end_line, end_col) = pos(source, b);
    Range {
        line,
        col,
        end_line,
        end_col,
    }
}

/// The outline of one document ([lsp.symbols]).
pub fn symbols(source: &str) -> Vec<Symbol> {
    let toks: Vec<Tok> = lex(source)
        .tokens
        .into_iter()
        .filter(|t| !t.kind.is_trivia() && t.kind != TokenKind::Pragma)
        .map(|t| {
            let text = t.text(source).to_string();
            Tok {
                kind: t.kind,
                up: text.to_ascii_uppercase(),
                text,
                start: t.span.start,
                end: t.span.end,
            }
        })
        .collect();
    let mut top: Vec<Symbol> = Vec::new();
    // open containers: (symbol, END keyword)
    let mut stack: Vec<(Symbol, &'static str)> = Vec::new();
    let mut in_var = false;
    let mut in_type = false;
    let mut in_struct = false;
    let mut at_stmt = false; // the next identifier starts a declaration
    let mut i = 0;
    let is_word = |t: &Tok| matches!(t.kind, TokenKind::Ident | TokenKind::Keyword);
    while i < toks.len() {
        let t = &toks[i];
        let open = match t.up.as_str() {
            "PROGRAM" => Some((SymKind::Module, "END_PROGRAM", "PROGRAM")),
            "CONFIGURATION" => Some((SymKind::Module, "END_CONFIGURATION", "CONFIGURATION")),
            "FUNCTION_BLOCK" => Some((SymKind::Class, "END_FUNCTION_BLOCK", "FUNCTION_BLOCK")),
            "FUNCTION" => Some((SymKind::Function, "END_FUNCTION", "FUNCTION")),
            "METHOD" => Some((SymKind::Method, "END_METHOD", "METHOD")),
            "INTERFACE" => Some((SymKind::Interface, "END_INTERFACE", "INTERFACE")),
            "TEST" => Some((SymKind::Test, "END_TEST", "TEST")),
            _ => None,
        };
        if is_word(t) && !in_var && !in_type {
            if let Some((kind, end, detail)) = open {
                // METHOD may carry an access modifier before its name
                let mut j = i + 1;
                while toks.get(j).is_some_and(|x| {
                    matches!(
                        x.up.as_str(),
                        "PUBLIC" | "PRIVATE" | "PROTECTED" | "INTERNAL" | "FINAL" | "ABSTRACT"
                    )
                }) {
                    j += 1;
                }
                // `PROGRAM Run WITH Main : PRG_Main;` in a resource is an
                // instance, not a declaration
                let instance = toks
                    .get(j + 1)
                    .is_some_and(|x| x.up == "WITH" || x.kind == TokenKind::Colon);
                if let Some(n) = toks
                    .get(j)
                    .filter(|n| n.kind == TokenKind::Ident && !instance)
                {
                    stack.push((
                        Symbol {
                            name: n.text.clone(),
                            kind,
                            range: range(source, t.start, t.end),
                            selection: range(source, n.start, n.end),
                            detail: detail.into(),
                            children: Vec::new(),
                        },
                        end,
                    ));
                    i = j + 1;
                    continue;
                }
            }
        }
        if t.up.starts_with("END_") {
            match t.up.as_str() {
                "END_VAR" => {
                    in_var = false;
                    // a global list outside a POU closes here
                    if let Some((s, "END_VAR")) = stack.last() {
                        let _ = s;
                        let (mut s, _) = stack.pop().expect("open");
                        s.range.end_line = pos(source, t.end).0;
                        s.range.end_col = pos(source, t.end).1;
                        attach(&mut stack, &mut top, s);
                    }
                }
                "END_TYPE" => in_type = false,
                "END_STRUCT" => {
                    in_struct = false;
                    if let Some((s, "END_STRUCT")) = stack.last() {
                        let _ = s;
                        let (mut s, _) = stack.pop().expect("open");
                        s.range.end_line = pos(source, t.end).0;
                        s.range.end_col = pos(source, t.end).1;
                        attach(&mut stack, &mut top, s);
                    }
                }
                end => {
                    if let Some(k) = stack.iter().rposition(|(_, e)| *e == end) {
                        while stack.len() > k {
                            let (mut s, _) = stack.pop().expect("open");
                            s.range.end_line = pos(source, t.end).0;
                            s.range.end_col = pos(source, t.end).1;
                            attach(&mut stack, &mut top, s);
                        }
                    }
                }
            }
            i += 1;
            continue;
        }
        if t.up.starts_with("VAR") && t.kind == TokenKind::Keyword {
            in_var = true;
            at_stmt = true;
            if (t.up == "VAR_GLOBAL") && stack.is_empty() {
                stack.push((
                    Symbol {
                        name: "VAR_GLOBAL".into(),
                        kind: SymKind::Globals,
                        range: range(source, t.start, t.end),
                        selection: range(source, t.start, t.end),
                        detail: "global variables".into(),
                        children: Vec::new(),
                    },
                    "END_VAR",
                ));
            }
            i += 1;
            // qualifiers after the section keyword
            while toks.get(i).is_some_and(|x| {
                matches!(
                    x.up.as_str(),
                    "CONSTANT" | "RETAIN" | "NON_RETAIN" | "PERSISTENT"
                )
            }) {
                i += 1;
            }
            continue;
        }
        if t.up == "TYPE" && t.kind == TokenKind::Keyword {
            in_type = true;
            at_stmt = true;
            i += 1;
            continue;
        }
        if t.kind == TokenKind::Semicolon {
            at_stmt = true;
            i += 1;
            continue;
        }
        // a declaration: names (comma separated) then ':'
        if (in_var || in_type) && at_stmt && t.kind == TokenKind::Ident {
            let mut names = vec![i];
            let mut j = i + 1;
            while toks.get(j).is_some_and(|x| x.kind == TokenKind::Comma)
                && toks.get(j + 1).is_some_and(|x| x.kind == TokenKind::Ident)
            {
                names.push(j + 1);
                j += 2;
            }
            // AT %IX0.0 between the name and ':'
            if toks.get(j).is_some_and(|x| x.up == "AT") {
                j += 2;
            }
            if toks.get(j).is_some_and(|x| x.kind == TokenKind::Colon) {
                // the type text up to ';' or ':='
                let mut k = j + 1;
                let mut detail = Vec::new();
                while let Some(x) = toks.get(k) {
                    if matches!(x.kind, TokenKind::Semicolon | TokenKind::Assign) {
                        break;
                    }
                    if in_type && x.up == "STRUCT" {
                        break;
                    }
                    detail.push(x.text.clone());
                    k += 1;
                    if detail.len() > 12 {
                        break;
                    }
                }
                let detail = detail.join(" ");
                let is_struct = in_type && toks.get(j + 1).is_some_and(|x| x.up == "STRUCT");
                for &n in &names {
                    let nt = &toks[n];
                    let kind = if in_type && !in_struct {
                        SymKind::Type
                    } else if in_struct {
                        SymKind::Field
                    } else {
                        SymKind::Variable
                    };
                    let sym = Symbol {
                        name: nt.text.clone(),
                        kind,
                        range: range(source, nt.start, nt.end),
                        selection: range(source, nt.start, nt.end),
                        detail: if is_struct {
                            "STRUCT".into()
                        } else {
                            detail.clone()
                        },
                        children: Vec::new(),
                    };
                    if is_struct {
                        stack.push((sym, "END_STRUCT"));
                        in_struct = true;
                    } else {
                        attach(&mut stack, &mut top, sym);
                    }
                }
                at_stmt = false;
                i = if is_struct { j + 2 } else { k };
                if is_struct {
                    at_stmt = true;
                }
                continue;
            }
        }
        at_stmt = false;
        i += 1;
    }
    // unclosed declarations (text being typed)
    while let Some((s, _)) = stack.pop() {
        attach(&mut stack, &mut top, s);
    }
    top
}

fn attach(stack: &mut [(Symbol, &'static str)], top: &mut Vec<Symbol>, s: Symbol) {
    match stack.last_mut() {
        Some((parent, _)) => parent.children.push(s),
        None => top.push(s),
    }
}

/// The identifier at a position, with its range.
fn word_at(source: &str, line: usize, col: usize) -> Option<String> {
    let text = source.lines().nth(line)?;
    let chars: Vec<char> = text.chars().collect();
    let is_id = |c: char| c.is_alphanumeric() || c == '_';
    let mut a = col.min(chars.len());
    if a == chars.len() || !is_id(chars[a]) {
        if a > 0 && is_id(chars[a - 1]) {
            a -= 1;
        } else {
            return None;
        }
    }
    let mut s = a;
    while s > 0 && is_id(chars[s - 1]) {
        s -= 1;
    }
    let mut e = a;
    while e < chars.len() && is_id(chars[e]) {
        e += 1;
    }
    Some(chars[s..e].iter().collect())
}

/// Where a declaration is: file and the name's range.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Location {
    /// File.
    pub path: PathBuf,
    /// The declared name.
    pub range: Range,
}

/// Go to the declaration of the name at a position ([lsp.definition]).
pub fn definition(
    files: &[(PathBuf, String)],
    path: &Path,
    line: usize,
    col: usize,
) -> Option<Location> {
    let (_, source) = files.iter().find(|(p, _)| same_file(p, path))?;
    let name = word_at(source, line, col)?;
    let syms = symbols(source);
    // the enclosing declarations, innermost first
    let mut chain: Vec<&Symbol> = Vec::new();
    let mut level: &[Symbol] = &syms;
    while let Some(s) = level.iter().find(|s| {
        let r = Range {
            end_line: s.range.end_line,
            end_col: s.range.end_col,
            ..s.range
        };
        r.contains(line, col) && !s.children.is_empty()
    }) {
        chain.push(s);
        level = &s.children;
    }
    for s in chain.iter().rev() {
        if let Some(c) = s
            .children
            .iter()
            .find(|c| c.name.eq_ignore_ascii_case(&name))
        {
            return Some(Location {
                path: path.to_path_buf(),
                range: c.selection,
            });
        }
    }
    // anywhere in the project: declarations, global variables, methods
    for (p, src) in files {
        for s in symbols(src) {
            if s.name.eq_ignore_ascii_case(&name) {
                return Some(Location {
                    path: p.clone(),
                    range: s.selection,
                });
            }
            for c in &s.children {
                let visible = s.kind == SymKind::Globals
                    || s.kind == SymKind::Module && s.detail == "CONFIGURATION"
                    || c.kind == SymKind::Method
                    || c.kind == SymKind::Globals;
                if visible && c.name.eq_ignore_ascii_case(&name) {
                    return Some(Location {
                        path: p.clone(),
                        range: c.selection,
                    });
                }
                for g in c.children.iter().filter(|_| c.kind == SymKind::Globals) {
                    if g.name.eq_ignore_ascii_case(&name) {
                        return Some(Location {
                            path: p.clone(),
                            range: g.selection,
                        });
                    }
                }
            }
        }
    }
    None
}

/// Hover text in Markdown ([lsp.hover]).
pub fn hover(
    files: &[(PathBuf, String)],
    diags: &[IdeDiag],
    path: &Path,
    line: usize,
    col: usize,
) -> Option<String> {
    for d in diags {
        let r = Range {
            line: d.line,
            col: d.col,
            end_line: d.end_line,
            end_col: d.end_col,
        };
        if r.contains(line, col) {
            if let Some(e) = crate::explain::explain(&d.code) {
                return Some(format!(
                    "**{}** ({}): {}\n\n{}",
                    e.code, e.severity, e.summary, e.text
                ));
            }
        }
    }
    let loc = definition(files, path, line, col)?;
    let (_, src) = files.iter().find(|(p, _)| same_file(p, &loc.path))?;
    let text = src.lines().nth(loc.range.line)?.trim();
    Some(format!("```st\n{text}\n```"))
}

/// Paths compare without regard to separators and (on Windows) case.
pub fn same_file(a: &Path, b: &Path) -> bool {
    let norm = |p: &Path| {
        let s = p.display().to_string().replace('\\', "/");
        if cfg!(windows) {
            s.to_ascii_lowercase()
        } else {
            s
        }
    };
    norm(a) == norm(b)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SRC: &str = "TYPE ST_Pos : STRUCT\n    x : INT;\n    y : INT;\nEND_STRUCT; END_TYPE\n\nFUNCTION_BLOCK FB_Motor\nVAR_INPUT\n    start, stop : BOOL;\nEND_VAR\nVAR\n    pos : ST_Pos;\nEND_VAR\nMETHOD PUBLIC Reset\nstart := FALSE;\nEND_METHOD\nstart := stop;\nEND_FUNCTION_BLOCK\n\nPROGRAM PRG_Main\nVAR m : FB_Motor; END_VAR\nm(start := TRUE);\nEND_PROGRAM\n";

    #[test]
    fn outline_of_declarations() {
        let s = symbols(SRC);
        let names: Vec<(&str, SymKind)> = s.iter().map(|x| (x.name.as_str(), x.kind)).collect();
        assert_eq!(
            names,
            [
                ("ST_Pos", SymKind::Type),
                ("FB_Motor", SymKind::Class),
                ("PRG_Main", SymKind::Module)
            ]
        );
        let fields: Vec<&str> = s[0].children.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(fields, ["x", "y"]);
        let fb: Vec<&str> = s[1].children.iter().map(|c| c.name.as_str()).collect();
        assert_eq!(fb, ["start", "stop", "pos", "Reset"]);
        assert_eq!(s[1].children[2].detail, "ST_Pos");
        assert_eq!(s[1].selection.line, 5);
        // still an outline while typing an unfinished block
        let partial = symbols("PROGRAM P\nVAR a : INT; END_VAR\na := ");
        assert_eq!(partial[0].children[0].name, "a");
    }

    #[test]
    fn definition_finds_locals_then_project() {
        let files = vec![(PathBuf::from("a.st"), SRC.to_string())];
        let p = Path::new("a.st");
        // `stop` in the FB body (line 15) -> its declaration on line 7
        let d = definition(&files, p, 15, 10).expect("found");
        assert_eq!((d.range.line, d.range.col), (7, 11));
        // `FB_Motor` in PRG_Main's declarations -> the block
        let d = definition(&files, p, 19, 10).expect("found");
        assert_eq!(d.range.line, 5);
        assert!(definition(&files, p, 4, 0).is_none());
    }

    #[test]
    fn diagnostics_and_hover() {
        let files = vec![(
            PathBuf::from("b.st"),
            "PROGRAM P\nVAR s : SINT; i : INT; END_VAR\ns := i;\nEND_PROGRAM\n".to_string(),
        )];
        let ds = project_diagnostics(files.clone(), &[]).expect("check");
        let d = &ds[0].1[0];
        assert_eq!((d.code.as_str(), d.severity, d.line), ("RP0103", 1, 2));
        let h = hover(&files, &ds[0].1, Path::new("b.st"), 2, d.col).expect("hover");
        assert!(h.starts_with("**RP0103** (error)"), "{h}");
        let h = hover(&files, &[], Path::new("b.st"), 2, 0).expect("hover");
        assert!(h.contains("s : SINT"), "{h}");
    }
}
