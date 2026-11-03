//! Parser: tokens to a lossless syntax tree (spec/03-variables.md,
//! spec/04-pous.md, spec/05-statements.md).
//!
//! Recursive descent for declarations and statements, precedence climbing for
//! expressions. On a syntax error the parser reports one diagnostic, skips to
//! a synchronisation point and continues, [syntax.recovery].

use crate::lexer::lex;
use crate::token::{Token, TokenKind};
use crate::tree::{Builder, Node, NodeKind as N};
use rootplc_diag::{Code, Diagnostic, Span, codes};

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
const POU_KWS: &[&str] = &["PROGRAM", "FUNCTION", "FUNCTION_BLOCK", "TYPE", "TEST"];
const STMT_KWS: &[&str] = &[
    "IF", "CASE", "FOR", "WHILE", "REPEAT", "EXIT", "CONTINUE", "RETURN",
];
/// Keywords that end a statement list.
const LIST_END_KWS: &[&str] = &[
    "END_PROGRAM",
    "END_FUNCTION",
    "END_FUNCTION_BLOCK",
    "END_TEST",
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

    fn at_any_kw(&self, kws: &[&str]) -> bool {
        kws.iter().any(|k| self.at_kw(k))
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
            if self.at_kw("PROGRAM") {
                self.pou(N::Program, "PROGRAM", "END_PROGRAM", false);
            } else if self.at_kw("FUNCTION_BLOCK") {
                self.pou(
                    N::FunctionBlock,
                    "FUNCTION_BLOCK",
                    "END_FUNCTION_BLOCK",
                    false,
                );
            } else if self.at_kw("FUNCTION") {
                self.pou(N::Function, "FUNCTION", "END_FUNCTION", true);
            } else if self.at_kw("TEST") {
                self.pou(N::Test, "TEST", "END_TEST", false);
            } else if self.at_kw("TYPE") {
                self.type_block();
            } else {
                self.unexpected("PROGRAM, FUNCTION, FUNCTION_BLOCK, TYPE or TEST");
                self.b.start(N::Error);
                self.bump();
                while !self.at_eof() && !self.at_any_kw(POU_KWS) {
                    self.bump();
                }
                self.b.finish();
            }
        }
        self.eat_trivia();
    }

    /// [pous.program], [pous.function], [pous.function-block], [pous.test], [pous.end].
    fn pou(&mut self, kind: N, open: &str, close: &str, has_type: bool) {
        self.b.start(kind);
        let open_span = self.span_here();
        self.bump();
        self.name();
        if has_type && self.expect(TokenKind::Colon, "':' and the return type") {
            self.type_spec();
        }
        while self.at_any_kw(SECTION_KWS) {
            self.var_section();
        }
        self.stmt_list(&[close]);
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
            if self.name() && self.expect(TokenKind::Colon, "':'") {
                self.type_spec();
                if self.eat(TokenKind::Assign) {
                    self.initializer();
                }
            }
            self.eat(TokenKind::Semicolon);
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
        self.bump();
        let _ = self.eat_kw("CONSTANT") || self.eat_kw("RETAIN") || self.eat_kw("NON_RETAIN");
        while !self.at_eof() && !self.at_kw("END_VAR") && !self.at_any_kw(POU_KWS) {
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
        if self.eat_kw("AT") {
            self.expect(TokenKind::DirectVariable, "a direct address such as %IX0.0");
        }
        if self.expect(TokenKind::Colon, "':' and a type") {
            self.type_spec();
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
                self.bump();
                if self.eat(TokenKind::LBracket) {
                    self.expr();
                    self.expect(TokenKind::RBracket, "']'");
                }
                if self.at(TokenKind::LParen) {
                    self.subrange_or_enum();
                }
            }
            Some(TokenKind::Ident) => {
                self.bump();
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
        let is_enum = self.nth_kind(1) == Some(TokenKind::Ident)
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

    fn struct_type(&mut self) {
        self.b.start(N::StructType);
        let open_span = self.span_here();
        self.bump(); // STRUCT
        while !self.at_eof() && !self.at_kw("END_STRUCT") && !self.at_any_kw(&["END_TYPE"]) {
            let before = self.pos;
            self.var_decl();
            if self.pos == before {
                self.recover(&["END_STRUCT"]);
                if self.pos == before {
                    self.bump();
                }
            }
        }
        if !self.eat_kw("END_STRUCT") {
            if self.at_eof() {
                self.error(
                    codes::MISSING_END,
                    "STRUCT is never closed: missing END_STRUCT".into(),
                    open_span,
                );
            } else {
                self.unexpected("'END_STRUCT'");
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
            && self.nth_kind(1) == Some(TokenKind::Ident)
            && self.nth_kind(2) == Some(TokenKind::Assign)
        {
            self.b.start(N::StructInit);
            self.bump();
            loop {
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
            && !self.at_any_kw(POU_KWS)
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
        } else if self.at_kw("IF") {
            self.if_stmt();
        } else if self.at_kw("CASE") {
            self.case_stmt();
        } else if self.at_kw("FOR") {
            self.for_stmt();
        } else if self.at_kw("WHILE") {
            self.while_stmt();
        } else if self.at_kw("REPEAT") {
            self.repeat_stmt();
        } else if self.at_kw("EXIT") {
            self.simple_kw_stmt(N::ExitStmt);
        } else if self.at_kw("CONTINUE") {
            self.simple_kw_stmt(N::ContinueStmt);
        } else if self.at_kw("RETURN") {
            self.simple_kw_stmt(N::ReturnStmt);
        } else if matches!(self.kind(), Some(TokenKind::Ident)) {
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
        if self.at(TokenKind::Assign) || self.at(TokenKind::AssignAttempt) {
            self.b.start_at(cp, N::AssignStmt);
            self.bump();
            if self.expr_start() {
                self.expr();
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
                    | TokenKind::DotDot,
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
        self.name();
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
            Some(TokenKind::Keyword) => self.at_any_kw(&["NOT", "TRUE", "FALSE", "NULL", "REF"]),
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
                if !self.eat(TokenKind::Integer) {
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
                if self.at(TokenKind::Ident)
                    && matches!(self.nth_kind(1), Some(TokenKind::Assign | TokenKind::Arrow))
                {
                    self.bump();
                    self.bump();
                }
                self.expr();
                self.b.finish();
                if !self.eat(TokenKind::Comma) {
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
        let src = "PROGRAM p VAR x : INT; END_VAR x := 1;";
        let p = parse(src);
        assert_eq!(p.diagnostics.len(), 1);
        assert_eq!(p.diagnostics[0].code.0, 202);
        assert_eq!(p.diagnostics[0].span.start, 0);
    }

    #[test]
    fn statements_and_types() {
        let src = "TYPE M : (A, B); R : INT (0..9); S : STRUCT a : INT; END_STRUCT END_TYPE
PROGRAM p VAR i : INT; m : M; END_VAR
CASE i OF 1, 2: i := 0; 3..5: ; ELSE i := 1; END_CASE
FOR i := 1 TO 3 DO EXIT; END_FOR
WHILE i < 3 DO i := i + 1; END_WHILE
REPEAT i := i - 1; UNTIL i = 0 END_REPEAT
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
