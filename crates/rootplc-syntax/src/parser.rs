//! Parser: tokens to a lossless syntax tree (spec/03-variables.md,
//! spec/04-pous.md, spec/05-statements.md).
//!
//! Recursive descent for declarations and statements, precedence climbing for
//! expressions. On a syntax error the parser reports one diagnostic, skips to
//! a synchronisation point and continues, [syntax.recovery].

use crate::lexer::lex;
use crate::token::{Token, TokenKind, is_soft_keyword};
use crate::tree::{Builder, Node, NodeKind as N};
use rootplc_diag::{Code, Diagnostic, Severity, Span, codes};

/// Output of [`parse`].
#[derive(Debug, Clone)]
pub struct Parse {
    /// Root node (kind `SourceFile`).
    pub tree: Node,
    /// All tokens, indexed by the tree.
    pub tokens: Vec<Token>,
    /// Lexical diagnostics.
    pub lex_diagnostics: Vec<Diagnostic>,
    /// Parse-stage diagnostics.
    pub diagnostics: Vec<Diagnostic>,
}

/// Lex and parse a source file.
pub fn parse(source: &str) -> Parse {
    let lexed = lex(source);
    let mut p = Parser {
        src: source,
        toks: &lexed.tokens,
        pos: 0,
        b: Builder::default(),
        diags: Vec::new(),
        in_property: false,
    };
    p.source_file();
    Parse {
        tree: p.b.into_root(),
        tokens: lexed.tokens.clone(),
        lex_diagnostics: lexed.diagnostics,
        diagnostics: p.diags,
    }
}

const SECTION_KWS: &[&str] = &[
    "VAR",
    "VAR_INPUT",
    "VAR_OUTPUT",
    "VAR_IN_OUT",
    "VAR_TEMP",
    "VAR_STAT",
    "VAR_GLOBAL",
    "VAR_EXTERNAL",
];
const POU_KWS: &[&str] = &[
    "PROGRAM",
    "FUNCTION",
    "FUNCTION_BLOCK",
    "TYPE",
    "TEST",
    "INTERFACE",
];
/// Access and inheritance modifiers, [pous.oop.modifiers].
const MODIFIER_KWS: &[&str] = &[
    "PUBLIC",
    "PRIVATE",
    "PROTECTED",
    "INTERNAL",
    "ABSTRACT",
    "FINAL",
    "OVERRIDE",
];
const STMT_KWS: &[&str] = &[
    "IF", "CASE", "FOR", "WHILE", "REPEAT", "EXIT", "CONTINUE", "RETURN",
];
/// Keywords that end a statement list.
const LIST_END_KWS: &[&str] = &[
    "END_PROGRAM",
    "END_FUNCTION",
    "END_FUNCTION_BLOCK",
    "END_TEST",
    "END_METHOD",
    "END_ACTION",
    "END_CLASS",
    "END_IF",
    "END_CASE",
    "END_FOR",
    "END_WHILE",
    "END_REPEAT",
    "ELSE",
    "ELSIF",
    "UNTIL",
];

struct Parser<'a> {
    src: &'a str,
    toks: &'a [Token],
    pos: usize,
    b: Builder,
    diags: Vec<Diagnostic>,
    /// Inside a PROPERTY: GET, SET, END_GET and END_SET end statement lists.
    in_property: bool,
}

fn is_trivia(k: TokenKind) -> bool {
    k.is_trivia() || k == TokenKind::Pragma
}

impl<'a> Parser<'a> {
    // ------------------------------------------------------------ token access

    /// Index of the n-th significant token from the current position.
    fn nth_index(&self, n: usize) -> Option<usize> {
        let mut seen = 0;
        let mut i = self.pos;
        while i < self.toks.len() {
            if !is_trivia(self.toks[i].kind) {
                if seen == n {
                    return Some(i);
                }
                seen += 1;
            }
            i += 1;
        }
        None
    }

    fn nth_kind(&self, n: usize) -> Option<TokenKind> {
        self.nth_index(n).map(|i| self.toks[i].kind)
    }

    fn kind(&self) -> Option<TokenKind> {
        self.nth_kind(0)
    }

    fn text_at(&self, i: usize) -> &'a str {
        self.toks[i].text(self.src)
    }

    fn at_eof(&self) -> bool {
        self.nth_index(0).is_none()
    }

    fn at(&self, k: TokenKind) -> bool {
        self.kind() == Some(k)
    }

    fn nth_is_kw(&self, n: usize, kw: &str) -> bool {
        self.nth_index(n).is_some_and(|i| {
            self.toks[i].kind == TokenKind::Keyword && self.text_at(i).eq_ignore_ascii_case(kw)
        })
    }

    fn at_kw(&self, kw: &str) -> bool {
        self.nth_is_kw(0, kw)
    }

    /// The next token is `word` (a keyword or a plain name), for the
    /// CODESYS words PROPERTY, GET, SET that IEC 61131-3 does not reserve.
    fn at_word(&self, word: &str) -> bool {
        self.nth_index(0).is_some_and(|i| {
            matches!(self.toks[i].kind, TokenKind::Keyword | TokenKind::Ident)
                && self.text_at(i).eq_ignore_ascii_case(word)
        })
    }

    fn eat_word(&mut self, word: &str) -> bool {
        if self.at_word(word) {
            self.bump();
            true
        } else {
            false
        }
    }

    /// `TEST :` or `TEST,` in a variable section declares a variable named TEST.
    fn at_test_decl(&self) -> bool {
        self.at_kw("TEST") && matches!(self.nth_kind(1), Some(TokenKind::Colon | TokenKind::Comma))
    }

    /// The start of a statement: a name followed by `:=`, `.`, `(`, `[` or `^`,
    /// or a statement keyword.
    fn at_stmt_start(&self) -> bool {
        (matches!(self.kind(), Some(TokenKind::Ident))
            && matches!(
                self.nth_kind(1),
                Some(
                    TokenKind::Assign
                        | TokenKind::Dot
                        | TokenKind::LParen
                        | TokenKind::LBracket
                        | TokenKind::Caret
                )
            ))
            || self.at_any_kw(STMT_KWS)
    }

    /// The start of a variable section, including CODESYS VAR_INST.
    fn at_section(&self) -> bool {
        self.at_any_kw(SECTION_KWS) || self.at_word("VAR_INST")
    }

    /// `TEST` inside a body is a name (TcUnit's TEST function, or the result
    /// variable of a function called TEST), not the start of a test block.
    fn at_test_call(&self) -> bool {
        self.at_kw("TEST")
            && matches!(
                self.nth_kind(1),
                Some(TokenKind::LParen | TokenKind::Assign | TokenKind::Dot | TokenKind::Semicolon)
            )
            || (self.at_kw("TEST") && self.nth_is_kw(1, "REF"))
    }

    /// At the start of a method or property, or at a word closing one.
    fn at_member_boundary(&self) -> bool {
        if self.at_kw("METHOD")
            || self.at_kw("ACTION")
            || self.at_word("PROPERTY")
            || self.at_word("END_PROPERTY")
            || self.at_modified_member()
        {
            return true;
        }
        // a method may be called Get or Set; these words only matter in a
        // property, and a property may be called Set (`Set := x` in its GET)
        self.in_property
            && ["GET", "END_GET", "SET", "END_SET"]
                .iter()
                .any(|w| self.at_word(w))
            && !matches!(
                self.nth_kind(1),
                Some(TokenKind::Assign | TokenKind::Dot | TokenKind::LBracket | TokenKind::LParen)
            )
    }

    fn at_any_kw(&self, kws: &[&str]) -> bool {
        kws.iter().any(|k| self.at_kw(k))
    }

    /// A modifier (PUBLIC, OVERRIDE, ...) at the next token: a modifier word
    /// followed by another word. `OVERRIDE` is a soft keyword, so
    /// `FUNCTION OVERRIDE : REAL` and `Override : UINT` stay names.
    fn at_modifier(&self) -> bool {
        self.nth_index(0).is_some_and(|i| self.is_modifier_index(i))
    }

    fn is_modifier_index(&self, i: usize) -> bool {
        matches!(self.toks[i].kind, TokenKind::Keyword | TokenKind::Ident)
            && MODIFIER_KWS
                .iter()
                .any(|m| self.text_at(i).eq_ignore_ascii_case(m))
            && self.toks[i + 1..]
                .iter()
                .find(|t| !is_trivia(t.kind))
                .is_some_and(|t| matches!(t.kind, TokenKind::Ident | TokenKind::Keyword))
    }

    /// Attach trivia, then the next significant token.
    fn bump(&mut self) {
        while self.pos < self.toks.len() && is_trivia(self.toks[self.pos].kind) {
            self.b.token(self.pos);
            self.pos += 1;
        }
        if self.pos < self.toks.len() {
            self.b.token(self.pos);
            self.pos += 1;
        }
    }

    /// Attach any remaining trivia (used at the end of the file).
    fn eat_trivia(&mut self) {
        while self.pos < self.toks.len() && is_trivia(self.toks[self.pos].kind) {
            self.b.token(self.pos);
            self.pos += 1;
        }
    }

    fn eat(&mut self, k: TokenKind) -> bool {
        if self.at(k) {
            self.bump();
            true
        } else {
            false
        }
    }

    fn eat_kw(&mut self, kw: &str) -> bool {
        if self.at_kw(kw) {
            self.bump();
            true
        } else {
            false
        }
    }

    // ------------------------------------------------------------ diagnostics

    fn span_here(&self) -> Span {
        match self.nth_index(0) {
            Some(i) => self.toks[i].span,
            None => Span::new(self.src.len(), self.src.len()),
        }
    }

    /// End of the previous significant token.
    fn span_prev_end(&self) -> Span {
        let mut i = self.pos;
        while i > 0 {
            i -= 1;
            if !is_trivia(self.toks[i].kind) {
                let e = self.toks[i].span.end as usize;
                return Span::new(e, e);
            }
        }
        Span::new(0, 0)
    }

    fn found(&self) -> String {
        match self.nth_index(0) {
            Some(i) => format!("'{}'", self.text_at(i)),
            None => "end of file".to_string(),
        }
    }

    fn error(&mut self, code: Code, msg: String, span: Span) {
        self.diags.push(Diagnostic::new(code, msg, span));
    }

    fn unexpected(&mut self, expected: &str) {
        let msg = format!("expected {expected}, found {}", self.found());
        let span = self.span_here();
        self.error(codes::SYNTAX_ERROR, msg, span);
    }

    fn expect(&mut self, k: TokenKind, what: &str) -> bool {
        if self.eat(k) {
            true
        } else {
            self.unexpected(what);
            false
        }
    }

    fn expect_kw(&mut self, kw: &str) -> bool {
        if self.eat_kw(kw) {
            true
        } else {
            self.unexpected(&format!("'{kw}'"));
            false
        }
    }

    /// A `;` terminator, [statements.terminator]. Reports RP0301 without
    /// consuming anything when it is missing.
    fn terminator(&mut self) {
        if !self.eat(TokenKind::Semicolon) {
            let span = self.span_prev_end();
            self.error(codes::MISSING_SEMICOLON, "missing ';'".to_string(), span);
        }
    }

    /// A name; a keyword or elementary type name here is RP0004.
    fn name(&mut self) -> bool {
        match self.kind() {
            Some(TokenKind::Ident) => {
                let i = self.nth_index(0).unwrap_or(self.pos);
                if is_soft_keyword(self.text_at(i)) {
                    let msg = format!(
                        "'{}' is reserved in IEC 61131-3; RootPLC accepts it as a name",
                        self.text_at(i)
                    );
                    self.error(codes::SOFT_KEYWORD_NAME, msg, self.toks[i].span);
                }
                self.bump();
                true
            }
            // [pous.test]: TEST is reserved only where a test block starts, so
            // a POU may be called TEST (TcUnit declares FUNCTION TEST)
            Some(TokenKind::Keyword) if self.at_kw("TEST") => {
                self.bump();
                true
            }
            // [lexical.keywords.soft]: a member or enumeration value may be
            // called NULL or REF (used as E.NULL, x.Ref)
            Some(TokenKind::Keyword) if self.at_kw("NULL") || self.at_kw("REF") => {
                let i = self.nth_index(0).unwrap_or(self.pos);
                let msg = format!(
                    "'{}' is reserved in IEC 61131-3; RootPLC accepts it as a name (use it after '.')",
                    self.text_at(i)
                );
                self.error(codes::SOFT_KEYWORD_NAME, msg, self.toks[i].span);
                self.bump();
                true
            }
            Some(TokenKind::Keyword | TokenKind::TypeName)
                if !self.at_any_kw(&["END_VAR", "END_STRUCT", "END_TYPE"]) =>
            {
                let i = self.nth_index(0).unwrap_or(self.pos);
                let span = self.toks[i].span;
                let msg = format!(
                    "'{}' is reserved and cannot be used as a name",
                    self.text_at(i)
                );
                self.error(codes::KEYWORD_AS_IDENTIFIER, msg, span);
                self.bump();
                true
            }
            _ => {
                self.unexpected("a name");
                false
            }
        }
    }

    /// A name, possibly qualified by namespaces: `Lib.Type`, [pous.type-spec].
    fn qualified_name(&mut self) -> bool {
        let ok = self.name();
        while ok && self.at(TokenKind::Dot) && self.nth_kind(1) == Some(TokenKind::Ident) {
            self.bump();
            self.bump();
        }
        ok
    }

    /// Skip tokens into an Error node until a sync point, [syntax.recovery].
    /// Always consumes at least one token unless at a sync point already.
    fn recover(&mut self, extra_stop: &[&str]) {
        self.b.start(N::Error);
        let mut first = true;
        while !self.at_eof() {
            if self.at(TokenKind::Semicolon) {
                self.bump();
                break;
            }
            let stop = self.at_any_kw(LIST_END_KWS)
                || self.at_any_kw(STMT_KWS)
                || self.at_any_kw(POU_KWS)
                || self.at_any_kw(SECTION_KWS)
                || self.at_any_kw(&["END_VAR", "END_TYPE", "END_STRUCT", "END_CASE"])
                || self.at_any_kw(extra_stop);
            if stop && !first {
                break;
            }
            if stop && first && !self.at_kw("ELSE") {
                // At a sync keyword already: do not consume it.
                break;
            }
            self.bump();
            first = false;
        }
        self.b.finish();
    }

    // ------------------------------------------------------------ file and POUs

    fn source_file(&mut self) {
        self.b.start(N::SourceFile);
        while !self.at_eof() {
            self.top_item();
        }
        self.eat_trivia();
    }

    /// Keywords that start a declaration at the top level (or in a namespace).
    fn at_top_start(&self) -> bool {
        self.at_any_kw(POU_KWS)
            || self.at_any_kw(&[
                "VAR_GLOBAL",
                "CONFIGURATION",
                "CLASS",
                "NAMESPACE",
                "END_NAMESPACE",
                "USING",
                "METHOD",
                "ACTION",
            ])
            || self.at_word("PROPERTY")
            || self.at_modified_member()
    }

    /// One declaration at the top level or inside a namespace.
    fn top_item(&mut self) {
        if self.at_kw("PROGRAM") {
            self.pou(N::Program, "PROGRAM", "END_PROGRAM", false);
        } else if self.at_kw("FUNCTION_BLOCK") {
            self.pou(
                N::FunctionBlock,
                "FUNCTION_BLOCK",
                "END_FUNCTION_BLOCK",
                false,
            );
        } else if self.at_kw("CLASS") {
            // [pous.oop.class]: a class is a function block without a body
            self.pou(N::FunctionBlock, "CLASS", "END_CLASS", false);
        } else if self.at_kw("FUNCTION") {
            self.pou(N::Function, "FUNCTION", "END_FUNCTION", true);
        } else if self.at_kw("TEST") {
            self.pou(N::Test, "TEST", "END_TEST", false);
        } else if self.at_kw("TYPE") {
            self.type_block();
        } else if self.at_kw("INTERFACE") {
            self.interface();
        } else if self.at_kw("VAR_GLOBAL") {
            // [config.global-list]: a global variable list of its own
            let sp = self.span_here();
            self.error(
                codes::VENDOR_SYNTAX,
                "VAR_GLOBAL outside a CONFIGURATION or POU is a CODESYS / TwinCAT global variable list; IEC 61131-3 declares global variables in a CONFIGURATION or RESOURCE".into(),
                sp,
            );
            self.b.start(N::GlobalVarList);
            self.var_section();
            self.b.finish();
        } else if self.at_kw("CONFIGURATION") {
            self.configuration();
        } else if self.at_kw("NAMESPACE") {
            self.namespace();
        } else if self.at_kw("USING") {
            self.using();
        } else if self.at_kw("METHOD")
            || self.at_kw("ACTION")
            || self.at_word("PROPERTY")
            || self.at_modified_member()
        {
            // [pous.action]: CODESYS exports members after their block
            self.members("END_FUNCTION_BLOCK");
        } else {
            self.unexpected(
                "PROGRAM, FUNCTION, FUNCTION_BLOCK, TYPE, TEST, VAR_GLOBAL or CONFIGURATION",
            );
            self.b.start(N::Error);
            self.bump();
            while !self.at_eof() && !self.at_top_start() {
                self.bump();
            }
            self.b.finish();
        }
    }

    /// [pous.namespace]: `NAMESPACE name … END_NAMESPACE`.
    fn namespace(&mut self) {
        self.b.start(N::Namespace);
        let open_span = self.span_here();
        self.bump();
        self.qualified_name();
        while !self.at_eof() && !self.at_kw("END_NAMESPACE") {
            let before = self.pos;
            self.top_item();
            if self.pos == before {
                self.bump();
            }
        }
        if !self.eat_kw("END_NAMESPACE") {
            self.error(
                codes::MISSING_END,
                "NAMESPACE is never closed: missing END_NAMESPACE".into(),
                open_span,
            );
        }
        self.b.finish();
    }

    /// [pous.namespace]: `USING name {, name};`.
    fn using(&mut self) {
        self.b.start(N::Using);
        self.bump();
        self.qualified_name();
        while self.eat(TokenKind::Comma) {
            self.qualified_name();
        }
        self.terminator();
        self.b.finish();
    }

    /// Modifiers, then METHOD, PROPERTY or ACTION (truST style: `PUBLIC METHOD M`).
    fn at_modified_member(&self) -> bool {
        let mut k = 0;
        while self.nth_index(k).is_some_and(|i| self.is_modifier_index(i)) {
            k += 1;
        }
        k > 0
            && self.nth_index(k).is_some_and(|i| {
                let t = self.text_at(i);
                ["METHOD", "PROPERTY", "ACTION"]
                    .iter()
                    .any(|w| t.eq_ignore_ascii_case(w))
            })
    }

    /// [pous.program], [pous.function], [pous.function-block], [pous.test], [pous.end].
    fn pou(&mut self, kind: N, open: &str, close: &str, has_type: bool) {
        self.b.start(kind);
        let open_span = self.span_here();
        let mark = self.diags.len();
        self.bump();
        let oop = matches!(kind, N::FunctionBlock | N::Program);
        // [pous.oop.modifiers]: FUNCTION INTERNAL F (TwinCAT library access)
        if oop || kind == N::Function {
            while self.at_modifier() {
                self.bump();
            }
        }
        self.name();
        if oop {
            self.extends_implements();
        }
        if has_type {
            if self.eat(TokenKind::Colon) {
                self.type_spec();
            } else if self.at_section() || self.at_kw(close) || self.at_stmt_start() {
                // [pous.function]: CODESYS and TwinCAT allow a function without a result
                let sp = self.span_prev_end();
                self.error(
                    codes::FUNCTION_WITHOUT_RESULT,
                    "FUNCTION without a result type is a vendor extension; call it as a statement"
                        .into(),
                    sp,
                );
            } else {
                self.expect(TokenKind::Colon, "':' and the return type");
            }
        }
        // TwinCAT accepts a ';' after the declaration header
        if self.at(TokenKind::Semicolon) {
            let sp = self.span_here();
            self.error(
                codes::VENDOR_SYNTAX,
                "';' after the declaration header is a TwinCAT form; IEC 61131-3 has none".into(),
                sp,
            );
            self.bump();
        }
        while self.at_section() {
            self.var_section();
        }
        if oop {
            self.members(close);
        }
        self.stmt_list(&[close]);
        if oop {
            self.members(close);
        }
        if !self.eat_kw(close) {
            // [pous.end]: a CODESYS object export ends the POU with the file
            let clean = self.diags[mark..]
                .iter()
                .all(|d| d.severity != Severity::Error);
            let exported = matches!(kind, N::Program | N::FunctionBlock | N::Function);
            if self.at_eof() && clean && exported {
                self.error(
                    codes::POU_CLOSED_BY_EOF,
                    format!("{open} is closed by the end of the file (CODESYS export); IEC 61131-3 writes {close}"),
                    open_span,
                );
            } else if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    format!("{open} is never closed: missing {close}"),
                    open_span,
                );
            } else {
                self.unexpected(&format!("'{close}'"));
            }
        }
        self.b.finish();
    }

    /// [config.configuration]: `CONFIGURATION name … END_CONFIGURATION`.
    fn configuration(&mut self) {
        self.b.start(N::Configuration);
        let open_span = self.span_here();
        self.bump();
        self.name();
        self.config_items("END_CONFIGURATION");
        self.close_config("CONFIGURATION", "END_CONFIGURATION", open_span);
        self.b.finish();
    }

    /// Global sections, resources, tasks and program instances up to `close`.
    fn config_items(&mut self, close: &str) {
        const STOP: &[&str] = &[
            "FUNCTION",
            "FUNCTION_BLOCK",
            "TYPE",
            "TEST",
            "CONFIGURATION",
        ];
        while !self.at_eof() && !self.at_kw(close) && !self.at_any_kw(STOP) {
            let before = self.pos;
            if self.at_section() {
                self.var_section();
            } else if self.at_kw("VAR_CONFIG") {
                // [config.var-config]: instance paths with addresses; recorded only
                self.b.start(N::VarSection);
                self.bump();
                while !self.at_eof() && !self.at_kw("END_VAR") && !self.at_kw(close) {
                    self.bump();
                }
                self.expect_kw("END_VAR");
                self.b.finish();
            } else if self.at_kw("RESOURCE") {
                self.b.start(N::Resource);
                let open_span = self.span_here();
                self.bump();
                self.name();
                if self.eat_word("ON") {
                    self.name();
                } else {
                    self.unexpected("'ON'");
                }
                self.config_items("END_RESOURCE");
                self.close_config("RESOURCE", "END_RESOURCE", open_span);
                self.b.finish();
            } else if self.at_word("TASK") {
                // [config.task]
                self.b.start(N::TaskConfig);
                self.bump();
                self.name();
                if self.at(TokenKind::LParen) {
                    self.arg_list();
                }
                self.terminator();
                self.b.finish();
            } else if self.at_kw("PROGRAM") {
                // [config.program-instance]
                self.b.start(N::ProgramConfig);
                self.bump();
                let _ = self.eat_kw("RETAIN") || self.eat_kw("NON_RETAIN");
                self.name();
                if self.eat_word("WITH") {
                    self.name();
                }
                if self.expect(TokenKind::Colon, "':' and the program type") {
                    self.name();
                }
                if self.at(TokenKind::LParen) {
                    self.arg_list();
                }
                self.terminator();
                self.b.finish();
            } else {
                self.unexpected("VAR_GLOBAL, RESOURCE, TASK or PROGRAM");
                self.recover(&[close, "RESOURCE", "TASK"]);
            }
            if self.pos == before {
                self.bump();
            }
        }
    }

    fn close_config(&mut self, open: &str, close: &str, open_span: Span) {
        if !self.eat_kw(close) {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    format!("{open} is never closed: missing {close}"),
                    open_span,
                );
            } else {
                self.unexpected(&format!("'{close}'"));
            }
        }
    }

    /// `EXTENDS base` and `IMPLEMENTS I1, I2`, [pous.oop.extends], [pous.oop.implements].
    fn extends_implements(&mut self) {
        if self.at_kw("EXTENDS") {
            self.b.start(N::Extends);
            self.bump();
            self.qualified_name();
            while self.eat(TokenKind::Comma) {
                self.qualified_name();
            }
            self.b.finish();
        }
        if self.at_kw("IMPLEMENTS") {
            self.b.start(N::Implements);
            self.bump();
            self.qualified_name();
            while self.eat(TokenKind::Comma) {
                self.qualified_name();
            }
            self.b.finish();
        }
    }

    /// Methods and properties of a function block, program or interface.
    fn members(&mut self, close: &str) {
        loop {
            let lead = self.at_modified_member();
            let mut k = 0;
            if lead {
                while self.nth_index(k).is_some_and(|i| self.is_modifier_index(i)) {
                    k += 1;
                }
            }
            let word = self
                .nth_index(k)
                .map(|i| self.text_at(i).to_ascii_uppercase())
                .unwrap_or_default();
            if word == "METHOD" && (lead || self.at_kw("METHOD")) {
                self.method();
            } else if word == "ACTION" && (lead || self.at_kw("ACTION")) {
                self.action();
            } else if word == "PROPERTY" && (lead || self.at_word("PROPERTY")) {
                self.property();
            } else if self.at_word("END_PROPERTY") {
                // a closing word without its opening: report and skip it
                self.unexpected(&format!("a METHOD, PROPERTY or '{close}'"));
                self.b.start(N::Error);
                self.bump();
                self.b.finish();
            } else {
                break;
            }
        }
    }

    /// [pous.oop.method]: `METHOD {modifier} name [: type] … END_METHOD`.
    fn method(&mut self) {
        self.b.start(N::Method);
        let open_span = self.span_here();
        while self.at_modifier() {
            self.bump();
        }
        self.bump();
        while self.at_modifier() {
            self.bump();
        }
        self.name();
        if self.eat(TokenKind::Colon) {
            self.type_spec();
        }
        self.eat(TokenKind::Semicolon);
        while self.at_section() {
            self.var_section();
        }
        self.stmt_list(&["END_METHOD"]);
        if !self.eat_kw("END_METHOD") {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    "METHOD is never closed: missing END_METHOD".into(),
                    open_span,
                );
            } else {
                self.unexpected("'END_METHOD'");
            }
        }
        self.b.finish();
    }

    /// [pous.action]: `ACTION name [:] statement_list END_ACTION`.
    fn action(&mut self) {
        self.b.start(N::Action);
        let open_span = self.span_here();
        while self.at_modifier() {
            self.bump();
        }
        self.bump();
        self.name();
        self.eat(TokenKind::Colon);
        while self.at_section() {
            self.var_section();
        }
        self.stmt_list(&["END_ACTION"]);
        if !self.eat_kw("END_ACTION") {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    "ACTION is never closed: missing END_ACTION".into(),
                    open_span,
                );
            } else {
                self.unexpected("'END_ACTION'");
            }
        }
        self.b.finish();
    }

    /// [pous.oop.property]: `PROPERTY {modifier} name : type [GET …] [SET …] END_PROPERTY`.
    fn property(&mut self) {
        self.b.start(N::Property);
        let open_span = self.span_here();
        // [pous.oop.property]: not part of IEC 61131-3
        self.error(
            codes::VENDOR_SYNTAX,
            "PROPERTY is a CODESYS / TwinCAT construct; IEC 61131-3 uses methods".into(),
            open_span,
        );
        while self.at_modifier() {
            self.bump();
        }
        self.bump();
        while self.at_modifier() {
            self.bump();
        }
        self.name();
        if self.expect(TokenKind::Colon, "':' and the property type") {
            self.type_spec();
        }
        self.eat(TokenKind::Semicolon);
        while self.at_section() {
            self.var_section();
        }
        let saved = self.in_property;
        self.in_property = true;
        for (open, close, kind) in [
            ("GET", "END_GET", N::PropertyGet),
            ("SET", "END_SET", N::PropertySet),
        ] {
            if self.at_word(open) {
                self.b.start(kind);
                self.bump();
                // [pous.oop.modifiers]: GET PUBLIC (TwinCAT access per accessor)
                while self.at_modifier() {
                    self.bump();
                }
                while self.at_section() {
                    self.var_section();
                }
                self.stmt_list(&[]);
                if !self.eat_word(close) {
                    self.unexpected(&format!("'{close}'"));
                }
                self.b.finish();
            }
        }
        self.in_property = saved;
        if !self.eat_word("END_PROPERTY") {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    "PROPERTY is never closed: missing END_PROPERTY".into(),
                    open_span,
                );
            } else {
                self.unexpected("'END_PROPERTY'");
            }
        }
        self.b.finish();
    }

    /// [pous.oop.interface]: `INTERFACE name [EXTENDS I {, I}] {method | property} END_INTERFACE`.
    fn interface(&mut self) {
        self.b.start(N::Interface);
        let open_span = self.span_here();
        self.bump();
        while self.at_modifier() {
            self.bump();
        }
        self.name();
        self.extends_implements();
        self.members("END_INTERFACE");
        if !self.eat_kw("END_INTERFACE") {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    "INTERFACE is never closed: missing END_INTERFACE".into(),
                    open_span,
                );
            } else {
                self.unexpected("'END_INTERFACE'");
                self.recover(&["END_INTERFACE"]);
                self.eat_kw("END_INTERFACE");
            }
        }
        self.b.finish();
    }

    /// [pous.type-block].
    fn type_block(&mut self) {
        self.b.start(N::TypeBlock);
        let open_span = self.span_here();
        self.bump();
        while !self.at_eof() && !self.at_kw("END_TYPE") && !self.at_any_kw(POU_KWS) {
            let before = self.pos;
            self.b.start(N::TypeDecl);
            while self.at_modifier() {
                self.bump();
            }
            let named = self.name();
            if named {
                // [types.derived.struct]: TYPE B EXTENDS A : STRUCT … END_STRUCT
                if self.at_kw("EXTENDS") {
                    let sp = self.span_here();
                    self.error(
                        codes::VENDOR_SYNTAX,
                        "a structure that EXTENDS another is a CODESYS / TwinCAT form; IEC 61131-3 has no structure inheritance".into(),
                        sp,
                    );
                }
                self.extends_implements();
            }
            if named && self.expect(TokenKind::Colon, "':'") {
                self.type_spec();
                if self.eat(TokenKind::Assign) {
                    self.initializer();
                }
            }
            if !self.eat(TokenKind::Semicolon) && named && !self.at_eof() {
                // [pous.type-block]: the ';' is optional in CODESYS
                let sp = self.span_prev_end();
                self.error(
                    codes::VENDOR_SYNTAX,
                    "no ';' after this type declaration; IEC 61131-3 ends each with ';'".into(),
                    sp,
                );
            }
            self.b.finish();
            if self.pos == before {
                self.recover(&[]);
                if self.pos == before {
                    self.bump();
                }
            }
        }
        if !self.eat_kw("END_TYPE") {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    "TYPE is never closed: missing END_TYPE".into(),
                    open_span,
                );
            } else {
                self.unexpected("'END_TYPE'");
            }
        }
        self.b.finish();
    }

    // ------------------------------------------------------------ declarations

    /// [variables.section].
    fn var_section(&mut self) {
        self.b.start(N::VarSection);
        let open_span = self.span_here();
        let section = self
            .text_at(self.nth_index(0).unwrap_or(self.pos))
            .to_ascii_uppercase();
        if section == "VAR_INST" {
            self.error(
                codes::VENDOR_SYNTAX,
                "VAR_INST is a CODESYS / TwinCAT section; IEC 61131-3 has none".into(),
                open_span,
            );
        }
        self.bump();
        // [variables.section]: CONSTANT / RETAIN / NON_RETAIN, ed.3 access
        // specifiers (VAR PUBLIC) and TwinCAT PERSISTENT, in any order
        while self.at_any_kw(&["CONSTANT", "RETAIN", "NON_RETAIN"])
            || self.at_modifier()
            || self.at_word("PERSISTENT")
        {
            let vendor = if self.at_word("PERSISTENT") {
                Some("PERSISTENT is a TwinCAT qualifier; IEC 61131-3 has none")
            } else if section == "VAR_IN_OUT" && self.at_kw("CONSTANT") {
                Some("VAR_IN_OUT CONSTANT is a CODESYS / TwinCAT section; IEC 61131-3 has none")
            } else {
                None
            };
            if let Some(msg) = vendor {
                let sp = self.span_here();
                self.error(codes::VENDOR_SYNTAX, msg.into(), sp);
            }
            self.bump();
        }
        while !self.at_eof()
            && !self.at_kw("END_VAR")
            && !(self.at_any_kw(POU_KWS) && !self.at_test_decl())
        {
            let before = self.pos;
            self.var_decl();
            if self.pos == before {
                self.recover(&[]);
                if self.pos == before {
                    self.bump();
                }
            }
        }
        if !self.eat_kw("END_VAR") {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    "VAR section is never closed: missing END_VAR".into(),
                    open_span,
                );
            } else {
                self.unexpected("'END_VAR'");
            }
        }
        self.b.finish();
    }

    /// [variables.declaration], [variables.located].
    fn var_decl(&mut self) {
        self.b.start(N::VarDecl);
        if !self.name() {
            self.b.finish();
            return;
        }
        while self.eat(TokenKind::Comma) {
            self.name();
        }
        if self.at_word("AT") && self.nth_kind(1) == Some(TokenKind::DirectVariable) {
            self.bump();
            self.expect(TokenKind::DirectVariable, "a direct address such as %IX0.0");
        }
        if self.expect(TokenKind::Colon, "':' and a type") {
            self.type_spec();
            if self.at(TokenKind::LParen) {
                // [variables.init-arguments]: fb : FB_X(arg := v) passes FB_init arguments
                let span = self.span_here();
                self.arg_list();
                self.error(
                    codes::INIT_ARGUMENTS_IGNORED,
                    "FB_init arguments are accepted but not run yet".into(),
                    span,
                );
            }
            if self.eat(TokenKind::Assign) {
                self.initializer();
            }
            self.terminator();
        } else {
            self.recover(&["END_VAR"]);
        }
        self.b.finish();
    }

    /// [pous.type-spec].
    fn type_spec(&mut self) {
        self.b.start(N::TypeSpec);
        match self.kind() {
            Some(TokenKind::TypeName) => {
                let is_string = self.nth_index(0).is_some_and(|i| {
                    let t = self.text_at(i);
                    t.eq_ignore_ascii_case("STRING") || t.eq_ignore_ascii_case("WSTRING")
                });
                self.bump();
                if self.eat(TokenKind::LBracket) {
                    self.expr();
                    self.expect(TokenKind::RBracket, "']'");
                } else if is_string && self.at(TokenKind::LParen) {
                    // [types.derived.string]: the CODESYS/TwinCAT spelling STRING(n)
                    let start = self.span_here();
                    self.bump();
                    self.expr();
                    if self.expect(TokenKind::RParen, "')'") {
                        let end = self.span_prev_end();
                        self.error(
                            codes::STRING_LENGTH_IN_PARENS,
                            "STRING(n) is a vendor spelling; IEC 61131-3 writes STRING[n]".into(),
                            Span::new(start.start as usize, end.end as usize),
                        );
                    }
                    self.b.finish();
                    return;
                }
                if self.at(TokenKind::LParen) {
                    self.subrange_or_enum();
                }
            }
            // [types.reference]: CODESYS POINTER TO T is read as REF_TO T
            Some(TokenKind::Ident) if self.at_word("POINTER") && self.nth_is_kw(1, "TO") => {
                let span = self.span_here();
                self.bump();
                self.bump();
                self.error(
                    codes::POINTER_TYPE,
                    "POINTER TO is a vendor type; RootPLC reads it as REF_TO (no pointer arithmetic)".into(),
                    span,
                );
                self.type_spec();
            }
            // [types.reference.alias]: CODESYS REFERENCE TO T
            Some(TokenKind::Ident) if self.at_word("REFERENCE") && self.nth_is_kw(1, "TO") => {
                let span = self.span_here();
                self.bump();
                self.bump();
                self.error(
                    codes::REFERENCE_TYPE,
                    "REFERENCE TO is a vendor type; uses read and write its target".into(),
                    span,
                );
                self.type_spec();
            }
            // [types.derived.union] (CODESYS / TwinCAT)
            Some(TokenKind::Ident) if self.at_word("UNION") => self.struct_type(),
            Some(TokenKind::Ident) => {
                self.qualified_name();
            }
            Some(TokenKind::LParen) => self.subrange_or_enum(),
            Some(TokenKind::Keyword) if self.at_kw("ARRAY") => self.array_type(),
            Some(TokenKind::Keyword) if self.at_kw("REF_TO") => {
                self.bump();
                self.type_spec();
            }
            Some(TokenKind::Keyword) if self.at_kw("STRUCT") => self.struct_type(),
            _ => self.unexpected("a type"),
        }
        self.b.finish();
    }

    /// `( … )` after a type name or on its own: a subrange or an enumeration.
    fn subrange_or_enum(&mut self) {
        // Enumeration if the first item is a name followed by `,`, `:=` or `)`.
        let first_name = self.nth_kind(1) == Some(TokenKind::Ident)
            || self.nth_index(1).is_some_and(|i| {
                self.toks[i].kind == TokenKind::Keyword
                    && ["NULL", "REF"]
                        .iter()
                        .any(|w| self.text_at(i).eq_ignore_ascii_case(w))
            });
        let is_enum = first_name
            && matches!(
                self.nth_kind(2),
                Some(TokenKind::Comma | TokenKind::Assign | TokenKind::RParen)
            );
        if is_enum {
            self.b.start(N::EnumType);
            self.bump(); // (
            loop {
                self.b.start(N::EnumValue);
                self.name();
                if self.eat(TokenKind::Assign) {
                    self.expr();
                }
                self.b.finish();
                if !self.eat(TokenKind::Comma) {
                    break;
                }
            }
            self.expect(TokenKind::RParen, "')'");
            // [types.derived.enum]: CODESYS/TwinCAT write the base type after the list
            if self.at(TokenKind::TypeName) {
                let span = self.span_here();
                let name = self.nth_index(0).map(|i| self.text_at(i)).unwrap_or("");
                let msg = format!(
                    "base type after the values is a vendor spelling; IEC 61131-3 writes {name} (...)"
                );
                self.bump();
                self.error(codes::ENUM_BASE_TYPE_AFTER, msg, span);
            }
            self.b.finish();
        } else {
            self.bump(); // (
            self.expr();
            self.expect(TokenKind::DotDot, "'..'");
            self.expr();
            self.expect(TokenKind::RParen, "')'");
        }
    }

    fn array_type(&mut self) {
        self.b.start(N::ArrayType);
        self.bump(); // ARRAY
        if self.expect(TokenKind::LBracket, "'['") {
            loop {
                self.b.start(N::ArrayDim);
                if !self.eat(TokenKind::Star) {
                    self.expr();
                    self.expect(TokenKind::DotDot, "'..'");
                    self.expr();
                }
                self.b.finish();
                if !self.eat(TokenKind::Comma) {
                    break;
                }
            }
            self.expect(TokenKind::RBracket, "']'");
        }
        if self.expect_kw("OF") {
            self.type_spec();
        }
        self.b.finish();
    }

    /// `STRUCT ... END_STRUCT`, or `UNION ... END_UNION` ([types.derived.union]).
    fn struct_type(&mut self) {
        self.b.start(N::StructType);
        let open_span = self.span_here();
        let (open, close) = if self.at_word("UNION") {
            self.error(
                codes::VENDOR_SYNTAX,
                "UNION is a CODESYS / TwinCAT type; IEC 61131-3 has none".into(),
                open_span,
            );
            ("UNION", "END_UNION")
        } else {
            ("STRUCT", "END_STRUCT")
        };
        self.bump(); // STRUCT or UNION
        if self.at_word(close) {
            // [types.derived.struct]: IEC 61131-3 declares at least one member
            let sp = self.span_here();
            self.error(
                codes::VENDOR_SYNTAX,
                format!("an empty {open} is a CODESYS / TwinCAT form; IEC 61131-3 declares at least one member"),
                sp,
            );
        }
        while !self.at_eof() && !self.at_word(close) && !self.at_any_kw(&["END_TYPE"]) {
            let before = self.pos;
            self.var_decl();
            if self.pos == before {
                self.recover(&[close]);
                if self.pos == before {
                    self.bump();
                }
            }
        }
        if !self.eat_word(close) {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    format!("{open} is never closed: missing {close}"),
                    open_span,
                );
            } else {
                self.unexpected(&format!("'{close}'"));
            }
        }
        self.b.finish();
    }

    /// [variables.initializer].
    fn initializer(&mut self) {
        self.b.start(N::Initializer);
        if self.at(TokenKind::LBracket) {
            self.b.start(N::ArrayInit);
            self.bump();
            if !self.at(TokenKind::RBracket) {
                loop {
                    self.initializer();
                    if !self.eat(TokenKind::Comma) {
                        break;
                    }
                }
            }
            self.expect(TokenKind::RBracket, "']'");
            self.b.finish();
        } else if self.at(TokenKind::LParen)
            && (self.nth_kind(1) == Some(TokenKind::RParen)
                || (self.nth_kind(1) == Some(TokenKind::Ident)
                    && self.nth_kind(2) == Some(TokenKind::Assign)))
        {
            self.b.start(N::StructInit);
            self.bump();
            // [variables.initializer]: `()` keeps every default
            if self.at(TokenKind::RParen) {
                let sp = self.span_prev_end();
                self.error(
                    codes::VENDOR_SYNTAX,
                    "an empty initializer '()' is a CODESYS / TwinCAT form; IEC 61131-3 omits the initializer".into(),
                    sp,
                );
            }
            while !self.at(TokenKind::RParen) {
                self.name();
                self.expect(TokenKind::Assign, "':='");
                self.initializer();
                if !self.eat(TokenKind::Comma) {
                    break;
                }
            }
            self.expect(TokenKind::RParen, "')'");
            self.b.finish();
        } else {
            self.expr();
        }
        self.b.finish();
    }

    // ------------------------------------------------------------ statements

    fn stmt_list(&mut self, extra_end: &[&str]) {
        self.b.start(N::StmtList);
        while !self.at_eof()
            && !self.at_any_kw(LIST_END_KWS)
            && !self.at_any_kw(extra_end)
            && !(self.at_any_kw(POU_KWS) && !self.at_test_call())
            && !self.at_member_boundary()
        {
            let before = self.pos;
            self.statement();
            if self.pos == before {
                self.recover(extra_end);
                if self.pos == before {
                    self.bump();
                }
            }
        }
        self.b.finish();
    }

    fn statement(&mut self) {
        if self.at(TokenKind::Semicolon) {
            self.b.start(N::EmptyStmt);
            self.bump();
            self.b.finish();
        } else if self.at_any_kw(&["IF", "CASE", "FOR", "WHILE", "REPEAT"]) {
            let open = self
                .text_at(self.nth_index(0).unwrap_or(self.pos))
                .to_ascii_uppercase();
            match open.as_str() {
                "IF" => self.if_stmt(),
                "CASE" => self.case_stmt(),
                "FOR" => self.for_stmt(),
                "WHILE" => self.while_stmt(),
                _ => self.repeat_stmt(),
            }
            // [statements.terminator]: IEC 61131-3 ends every statement with
            // ';', also IF ... END_IF; the ';' is an empty statement here
            if !self.at(TokenKind::Semicolon) && !self.at_eof() {
                let span = self.span_prev_end();
                self.error(
                    codes::VENDOR_SYNTAX,
                    format!("no ';' after this {open} statement; IEC 61131-3 ends every statement with ';'"),
                    span,
                );
            }
        } else if self.at_kw("EXIT") {
            self.simple_kw_stmt(N::ExitStmt);
        } else if self.at_kw("CONTINUE") {
            self.simple_kw_stmt(N::ContinueStmt);
        } else if self.at_kw("RETURN") {
            self.simple_kw_stmt(N::ReturnStmt);
        } else if matches!(self.kind(), Some(TokenKind::Ident))
            || self.at_any_kw(&["THIS", "SUPER"])
            || self.at_test_call()
        {
            self.assign_or_call();
        } else {
            self.unexpected("a statement");
            self.recover(&[]);
        }
    }

    /// [statements.control].
    fn simple_kw_stmt(&mut self, kind: N) {
        self.b.start(kind);
        self.bump();
        self.terminator();
        self.b.finish();
    }

    /// [statements.assignment], [statements.call].
    fn assign_or_call(&mut self) {
        let cp = self.b.checkpoint();
        self.postfix_expr();
        let ref_assign = self.at_kw("REF") && self.nth_kind(1) == Some(TokenKind::Eq);
        // [statements.assignment.set-reset]: x S= c; x R= c; (CODESYS / TwinCAT)
        let set_reset =
            (self.at_word("S") || self.at_word("R")) && self.nth_kind(1) == Some(TokenKind::Eq);
        if self.at(TokenKind::Assign)
            || self.at(TokenKind::AssignAttempt)
            || ref_assign
            || set_reset
        {
            self.b.start_at(cp, N::AssignStmt);
            self.bump();
            if ref_assign || set_reset {
                self.bump(); // the '=' of REF=, S=, R=
            }
            if self.expr_start() {
                self.assign_value();
            } else {
                self.unexpected("an expression");
                self.recover(&[]);
                self.b.finish();
                return;
            }
            self.terminator();
            self.b.finish();
        } else {
            self.b.start_at(cp, N::CallStmt);
            self.terminator();
            self.b.finish();
        }
    }

    /// The value of an assignment; `b := v` here makes a chain `a := b := v`
    /// ([statements.assignment.chain], CODESYS / TwinCAT): a nested AssignStmt.
    fn assign_value(&mut self) {
        let cp = self.b.checkpoint();
        self.expr();
        if self.at(TokenKind::Assign) {
            self.b.start_at(cp, N::AssignStmt);
            self.bump();
            self.assign_value();
            self.b.finish();
        }
    }

    /// [statements.if].
    fn if_stmt(&mut self) {
        self.b.start(N::IfStmt);
        let open = self.span_here();
        self.bump();
        self.expr();
        self.expect_kw("THEN");
        self.stmt_list(&[]);
        while self.at_kw("ELSIF") {
            self.bump();
            self.expr();
            self.expect_kw("THEN");
            self.stmt_list(&[]);
        }
        if self.eat_kw("ELSE") {
            self.stmt_list(&[]);
        }
        self.close_block("IF", "END_IF", open);
        self.b.finish();
    }

    fn close_block(&mut self, open: &str, close: &str, open_span: Span) {
        if !self.eat_kw(close) {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    format!("{open} is never closed: missing {close}"),
                    open_span,
                );
            } else {
                self.unexpected(&format!("'{close}'"));
            }
        }
    }

    /// True if the upcoming tokens form a case label list followed by `:`.
    fn at_case_label(&self) -> bool {
        let mut n = 0;
        loop {
            match self.nth_kind(n) {
                Some(TokenKind::Colon) => return n > 0,
                Some(
                    TokenKind::Integer
                    | TokenKind::TypedLiteral
                    | TokenKind::EnumLiteral
                    | TokenKind::Ident
                    | TokenKind::Char
                    | TokenKind::Minus
                    | TokenKind::Plus
                    | TokenKind::Comma
                    | TokenKind::DotDot
                    // E.V (CODESYS / TwinCAT enumeration value)
                    | TokenKind::Dot,
                ) => n += 1,
                _ => return false,
            }
        }
    }

    /// [statements.case].
    fn case_stmt(&mut self) {
        self.b.start(N::CaseStmt);
        let open = self.span_here();
        self.bump();
        self.expr();
        self.expect_kw("OF");
        while self.at_case_label() {
            self.b.start(N::CaseElement);
            loop {
                self.expr();
                if self.eat(TokenKind::DotDot) {
                    self.expr();
                }
                if !self.eat(TokenKind::Comma) {
                    break;
                }
            }
            self.expect(TokenKind::Colon, "':'");
            self.case_branch();
            self.b.finish();
        }
        if self.eat_kw("ELSE") {
            self.stmt_list(&["END_CASE"]);
        }
        self.close_block("CASE", "END_CASE", open);
        self.b.finish();
    }

    /// Statements of one case branch: up to the next label, ELSE or END_CASE.
    fn case_branch(&mut self) {
        self.b.start(N::StmtList);
        while !self.at_eof()
            && !self.at_case_label()
            && !self.at_any_kw(&["ELSE", "END_CASE"])
            && !self.at_any_kw(POU_KWS)
            && !self.at_any_kw(LIST_END_KWS)
        {
            let before = self.pos;
            self.statement();
            if self.pos == before {
                self.recover(&["END_CASE"]);
                if self.pos == before {
                    self.bump();
                }
            }
        }
        self.b.finish();
    }

    /// [statements.for].
    fn for_stmt(&mut self) {
        self.b.start(N::ForStmt);
        let open = self.span_here();
        self.bump();
        // [statements.for]: a variable, or (TwinCAT) an element or member
        if matches!(self.kind(), Some(TokenKind::Ident)) {
            let element = matches!(self.nth_kind(1), Some(TokenKind::Dot | TokenKind::LBracket));
            self.postfix_expr();
            if element {
                let sp = self.span_prev_end();
                self.error(
                    codes::VENDOR_SYNTAX,
                    "an element or member as FOR control variable is a TwinCAT form; IEC 61131-3 uses a variable".into(),
                    sp,
                );
            }
        } else {
            self.name();
        }
        self.expect(TokenKind::Assign, "':='");
        self.expr();
        self.expect_kw("TO");
        self.expr();
        if self.eat_kw("BY") {
            self.expr();
        }
        self.expect_kw("DO");
        self.stmt_list(&["END_FOR"]);
        self.close_block("FOR", "END_FOR", open);
        self.b.finish();
    }

    /// [statements.while].
    fn while_stmt(&mut self) {
        self.b.start(N::WhileStmt);
        let open = self.span_here();
        self.bump();
        self.expr();
        self.expect_kw("DO");
        self.stmt_list(&["END_WHILE"]);
        self.close_block("WHILE", "END_WHILE", open);
        self.b.finish();
    }

    /// [statements.repeat].
    fn repeat_stmt(&mut self) {
        self.b.start(N::RepeatStmt);
        let open = self.span_here();
        self.bump();
        self.stmt_list(&["UNTIL"]);
        if self.expect_kw("UNTIL") {
            self.expr();
        }
        self.close_block("REPEAT", "END_REPEAT", open);
        self.b.finish();
    }

    // ------------------------------------------------------------ expressions

    fn expr_start(&self) -> bool {
        match self.kind() {
            Some(
                TokenKind::Integer
                | TokenKind::Real
                | TokenKind::TypedLiteral
                | TokenKind::Duration
                | TokenKind::Date
                | TokenKind::TimeOfDay
                | TokenKind::DateAndTime
                | TokenKind::Char
                | TokenKind::String
                | TokenKind::WString
                | TokenKind::EnumLiteral
                | TokenKind::DirectVariable
                | TokenKind::Ident
                | TokenKind::LParen
                | TokenKind::Minus
                | TokenKind::Plus,
            ) => true,
            // TIME() (TwinCAT_BuiltIns)
            Some(TokenKind::TypeName) => {
                self.nth_kind(1) == Some(TokenKind::LParen)
                    && self.nth_kind(2) == Some(TokenKind::RParen)
            }
            // MOD(a, b): the standard function ([stdlib.functions.operators])
            Some(TokenKind::Keyword) if self.at_kw("MOD") => {
                self.nth_kind(1) == Some(TokenKind::LParen)
            }
            Some(TokenKind::Keyword) => self.at_any_kw(&[
                "NOT", "TRUE", "FALSE", "NULL", "REF", "THIS", "SUPER", "TEST",
            ]),
            _ => false,
        }
    }

    /// Binding power of the binary operator at the cursor, [statements.expression.precedence].
    fn binary_bp(&self) -> Option<u8> {
        let k = self.kind()?;
        Some(match k {
            TokenKind::Power => 8,
            TokenKind::Star | TokenKind::Slash => 7,
            TokenKind::Plus | TokenKind::Minus => 6,
            TokenKind::Lt | TokenKind::Gt | TokenKind::Le | TokenKind::Ge => 5,
            TokenKind::Eq | TokenKind::Neq => 4,
            TokenKind::Ampersand => 3,
            TokenKind::Keyword if self.at_kw("MOD") => 7,
            TokenKind::Keyword if self.at_kw("AND") || self.at_kw("AND_THEN") => 3,
            TokenKind::Keyword if self.at_kw("XOR") => 2,
            TokenKind::Keyword if self.at_kw("OR") || self.at_kw("OR_ELSE") => 1,
            _ => return None,
        })
    }

    fn expr(&mut self) {
        self.expr_bp(0);
    }

    fn expr_bp(&mut self, min_bp: u8) {
        let cp = self.b.checkpoint();
        self.unary_expr();
        while let Some(bp) = self.binary_bp() {
            if bp <= min_bp {
                break;
            }
            self.b.start_at(cp, N::BinExpr);
            self.bump(); // operator
            self.expr_bp(bp); // left-associative
            self.b.finish();
        }
    }

    fn unary_expr(&mut self) {
        if self.at(TokenKind::Minus) || self.at(TokenKind::Plus) || self.at_kw("NOT") {
            self.b.start(N::UnaryExpr);
            self.bump();
            self.unary_expr();
            self.b.finish();
        } else {
            self.postfix_expr();
        }
    }

    /// [statements.expression.access].
    fn postfix_expr(&mut self) {
        let cp = self.b.checkpoint();
        if !self.primary() {
            return;
        }
        loop {
            if self.at(TokenKind::Dot) {
                self.b.start_at(cp, N::MemberExpr);
                self.bump();
                // a member name is a use, not a declaration: no RP0124; after
                // '.' even a keyword is a member name (E_State.NULL, x.Ref)
                if !self.eat(TokenKind::Integer)
                    && !self.eat(TokenKind::Ident)
                    && !self.eat(TokenKind::Keyword)
                {
                    self.name();
                }
                self.b.finish();
            } else if self.at(TokenKind::LBracket) {
                self.b.start_at(cp, N::IndexExpr);
                self.bump();
                loop {
                    self.expr();
                    if !self.eat(TokenKind::Comma) {
                        break;
                    }
                }
                self.expect(TokenKind::RBracket, "']'");
                self.b.finish();
            } else if self.at(TokenKind::Caret) {
                self.b.start_at(cp, N::DerefExpr);
                self.bump();
                self.b.finish();
            } else if self.at(TokenKind::LParen) {
                self.b.start_at(cp, N::CallExpr);
                self.arg_list();
                self.b.finish();
            } else {
                break;
            }
        }
    }

    fn arg_list(&mut self) {
        self.b.start(N::ArgList);
        self.bump(); // (
        if !self.at(TokenKind::RParen) {
            loop {
                self.b.start(N::Arg);
                // a parameter may be called TEST ([pous.test])
                if (self.at(TokenKind::Ident) || self.at_kw("TEST"))
                    && matches!(self.nth_kind(1), Some(TokenKind::Assign | TokenKind::Arrow))
                {
                    self.bump();
                    self.bump();
                    // [statements.call]: `Done =>` with no variable ignores the
                    // output, `bExecute :=` with no value leaves the input as is
                    if !matches!(self.kind(), Some(TokenKind::Comma | TokenKind::RParen)) {
                        self.expr();
                    } else {
                        let sp = self.span_prev_end();
                        self.error(
                            codes::VENDOR_SYNTAX,
                            "an argument without a value is a CODESYS / TwinCAT form; IEC 61131-3 names a variable or value".into(),
                            sp,
                        );
                    }
                } else {
                    self.expr();
                }
                self.b.finish();
                if !self.eat(TokenKind::Comma) {
                    break;
                }
                // a comma before ')' (CODESYS / TwinCAT)
                if self.at(TokenKind::RParen) {
                    let sp = self.span_prev_end();
                    self.error(
                        codes::VENDOR_SYNTAX,
                        "a comma before ')' is a CODESYS / TwinCAT form; IEC 61131-3 has none"
                            .into(),
                        sp,
                    );
                    break;
                }
            }
        }
        self.expect(TokenKind::RParen, "')'");
        self.b.finish();
    }

    /// Returns false (after reporting) if no primary expression starts here.
    fn primary(&mut self) -> bool {
        match self.kind() {
            Some(
                TokenKind::Integer
                | TokenKind::Real
                | TokenKind::TypedLiteral
                | TokenKind::Duration
                | TokenKind::Date
                | TokenKind::TimeOfDay
                | TokenKind::DateAndTime
                | TokenKind::Char
                | TokenKind::String
                | TokenKind::WString
                | TokenKind::EnumLiteral
                | TokenKind::DirectVariable,
            ) => {
                self.b.start(N::Literal);
                self.bump();
                self.b.finish();
                true
            }
            Some(TokenKind::Keyword) if self.at_any_kw(&["TRUE", "FALSE", "NULL"]) => {
                self.b.start(N::Literal);
                self.bump();
                self.b.finish();
                true
            }
            Some(TokenKind::Keyword) if self.at_kw("REF") => {
                self.b.start(N::RefExpr);
                self.bump();
                if self.expect(TokenKind::LParen, "'('") {
                    self.expr();
                    self.expect(TokenKind::RParen, "')'");
                }
                self.b.finish();
                true
            }
            Some(TokenKind::Ident) => {
                self.b.start(N::NameRef);
                self.bump();
                self.b.finish();
                true
            }
            // an elementary type name as a call argument: SIZEOF(INT); TIME()
            // (TwinCAT_BuiltIns) is a call
            Some(TokenKind::TypeName)
                if matches!(self.nth_kind(1), Some(TokenKind::RParen | TokenKind::Comma))
                    || (self.nth_kind(1) == Some(TokenKind::LParen)
                        && self.nth_kind(2) == Some(TokenKind::RParen)) =>
            {
                self.b.start(N::NameRef);
                self.bump();
                self.b.finish();
                true
            }
            // [pous.oop.this]: THIS and SUPER, dereferenced with ^; TEST(...) is a
            // call; MOD(a, b) the standard function ([stdlib.functions.operators])
            Some(TokenKind::Keyword)
                if self.at_any_kw(&["THIS", "SUPER", "TEST"])
                    || (self.at_kw("MOD") && self.nth_kind(1) == Some(TokenKind::LParen)) =>
            {
                self.b.start(N::NameRef);
                self.bump();
                self.b.finish();
                true
            }
            Some(TokenKind::LParen) => {
                self.b.start(N::ParenExpr);
                self.bump();
                self.expr();
                self.expect(TokenKind::RParen, "')'");
                self.b.finish();
                true
            }
            _ => {
                self.unexpected("an expression");
                false
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn codes_of(src: &str) -> Vec<u16> {
        parse(src).diagnostics.iter().map(|d| d.code.0).collect()
    }

    #[test]
    fn lossless_round_trip() {
        let src =
            "PROGRAM p (* c *)\nVAR x : INT := 1; END_VAR\nx := x + 1; // done\nEND_PROGRAM\n";
        let p = parse(src);
        assert_eq!(p.tree.text(&p.tokens, src), src);
        assert!(p.diagnostics.is_empty(), "{:?}", p.diagnostics);
    }

    #[test]
    fn precedence_shapes_tree() {
        let src = "PROGRAM p VAR a : INT; END_VAR a := 2 + 3 * 4 ** 2; END_PROGRAM";
        let p = parse(src);
        assert!(p.diagnostics.is_empty());
        // 2 + (3 * (4 ** 2)) gives three nested binary expressions.
        assert_eq!(p.tree.count(N::BinExpr), 3);
    }

    #[test]
    fn keyword_as_name_is_rp0004() {
        assert_eq!(
            codes_of("PROGRAM p VAR end_if : INT; END_VAR END_PROGRAM"),
            [4]
        );
    }

    #[test]
    fn missing_semicolon_and_recovery() {
        let src = "PROGRAM p VAR x, y : INT; END_VAR x := 1\ny := * 2; END_PROGRAM";
        assert_eq!(codes_of(src), [301, 201]);
    }

    #[test]
    fn missing_end_reported_at_open() {
        let src = "TYPE T : STRUCT a : INT; END_STRUCT";
        let p = parse(src);
        assert_eq!(p.diagnostics.len(), 1);
        assert_eq!(p.diagnostics[0].code.0, 202);
        assert_eq!(p.diagnostics[0].span.start, 0);
    }

    #[test]
    fn pou_closed_by_end_of_file() {
        // [pous.end]: a CODESYS object export without END_PROGRAM
        let p = parse("PROGRAM p VAR x : INT; END_VAR x := 1;");
        assert_eq!(p.diagnostics.len(), 1);
        assert_eq!(p.diagnostics[0].code.0, 131);
        // with a syntax error inside it stays "never closed"
        assert_eq!(
            codes_of("PROGRAM p VAR x : INT; END_VAR x := ;"),
            [201, 202]
        );
    }

    #[test]
    fn statements_and_types() {
        let src = "TYPE M : (A, B); R : INT (0..9); S : STRUCT a : INT; END_STRUCT; END_TYPE
PROGRAM p VAR i : INT; m : M; END_VAR
CASE i OF 1, 2: i := 0; 3..5: ; ELSE i := 1; END_CASE;
FOR i := 1 TO 3 DO EXIT; END_FOR;
WHILE i < 3 DO i := i + 1; END_WHILE;
REPEAT i := i - 1; UNTIL i = 0 END_REPEAT;
END_PROGRAM";
        let p = parse(src);
        assert!(p.diagnostics.is_empty(), "{:?}", p.diagnostics);
        assert_eq!(p.tree.count(N::CaseElement), 2);
    }

    #[test]
    fn every_prefix_is_lossless_and_terminates() {
        let src = "TYPE M : (A, B := 2); S : STRUCT a : ARRAY[0..1] OF INT; END_STRUCT END_TYPE
FUNCTION_BLOCK FB VAR_INPUT i AT %IX0.0 : BOOL; END_VAR VAR_OUTPUT q : BOOL; END_VAR
IF i AND NOT q THEN q := TRUE; ELSIF i THEN ; ELSE q := FALSE; END_IF
END_FUNCTION_BLOCK
PROGRAM p VAR f : FB; n : INT := 3; r : REF_TO INT; END_VAR
f(i := TRUE, q => n); r := REF(n); r^ := -2 ** 2;
CASE n OF 1..2, 5: n := 0; ELSE n := n MOD 2; END_CASE (* {attribute 'x'} *)
END_PROGRAM";
        for end in (0..=src.len()).filter(|&e| src.is_char_boundary(e)) {
            let s = &src[..end];
            let p = parse(s);
            assert_eq!(p.tree.text(&p.tokens, s), s, "prefix {end}");
        }
        // Junk after the cut point too.
        for junk in [
            ";;;",
            "END_IF END_IF",
            ")))",
            "x := := 1;",
            "VAR",
            "CASE",
            "(* x",
        ] {
            let s = format!("PROGRAM p {junk} END_PROGRAM");
            let p = parse(&s);
            assert_eq!(p.tree.text(&p.tokens, &s), s, "junk {junk}");
        }
    }
}
