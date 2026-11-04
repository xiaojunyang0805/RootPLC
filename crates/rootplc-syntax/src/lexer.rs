//! The lexer: source text to tokens plus diagnostics (spec/01-lexical.md).
//!
//! It never stops at an error. Every byte ends up in exactly one token, and
//! each problem is reported once with its stable code.

use crate::token::{
    Token, TokenKind, is_elementary_type, is_keyword, is_known_pragma, is_soft_keyword,
};
use rootplc_diag::{Diagnostic, Span, codes};

/// Output of the lexer.
#[derive(Debug, Clone, Default)]
pub struct LexResult {
    /// All tokens, including trivia, in source order.
    pub tokens: Vec<Token>,
    /// Lexical diagnostics, in source order.
    pub diagnostics: Vec<Diagnostic>,
}

/// Lex UTF-8 text, [lexical.source.encoding].
pub fn lex(source: &str) -> LexResult {
    let mut lx = Lexer {
        src: source,
        b: source.as_bytes(),
        pos: 0,
        out: LexResult::default(),
    };
    lx.run();
    lx.out
}

/// Lex raw bytes. Invalid UTF-8 is RP0005 at the first bad byte; the rest is
/// lexed from a lossy conversion, so later spans refer to that converted text.
pub fn lex_bytes(bytes: &[u8]) -> LexResult {
    match std::str::from_utf8(bytes) {
        Ok(s) => lex(s),
        Err(e) => {
            let text = String::from_utf8_lossy(bytes);
            let mut r = lex(&text);
            let at = e.valid_up_to();
            r.diagnostics.insert(
                0,
                Diagnostic::new(
                    codes::INVALID_CHARACTER,
                    "source is not valid UTF-8",
                    Span::new(at, at + 1),
                ),
            );
            r
        }
    }
}

struct Lexer<'a> {
    src: &'a str,
    b: &'a [u8],
    pos: usize,
    out: LexResult,
}

const DURATION_UNITS: [(&str, Option<u64>); 7] = [
    ("d", None),
    ("h", Some(24)),
    ("m", Some(60)),
    ("s", Some(60)),
    ("ms", Some(1000)),
    ("us", Some(1000)),
    ("ns", Some(1000)),
];

fn is_ws(c: u8) -> bool {
    matches!(c, b' ' | b'\t' | b'\n' | b'\r' | 0x0c)
}

fn is_ident_char(c: u8) -> bool {
    c.is_ascii_alphanumeric() || c == b'_'
}

impl<'a> Lexer<'a> {
    fn peek(&self, n: usize) -> u8 {
        self.b.get(self.pos + n).copied().unwrap_or(0)
    }

    fn at_end(&self) -> bool {
        self.pos >= self.b.len()
    }

    fn eat_while(&mut self, f: impl Fn(u8) -> bool) {
        while !self.at_end() && f(self.b[self.pos]) {
            self.pos += 1;
        }
    }

    /// Byte length of the char at `pos`.
    fn char_len(&self) -> usize {
        self.src[self.pos..]
            .chars()
            .next()
            .map_or(1, char::len_utf8)
    }

    fn push(&mut self, kind: TokenKind, start: usize) {
        self.out.tokens.push(Token {
            kind,
            span: Span::new(start, self.pos),
        });
    }

    fn diag(&mut self, code: rootplc_diag::Code, msg: impl Into<String>, start: usize, end: usize) {
        self.out
            .diagnostics
            .push(Diagnostic::new(code, msg, Span::new(start, end)));
    }

    fn run(&mut self) {
        if self.src.starts_with('\u{feff}') {
            self.pos = 3;
            self.push(TokenKind::Whitespace, 0);
        }
        while !self.at_end() {
            let start = self.pos;
            let c = self.b[self.pos];
            let kind = match c {
                c if is_ws(c) => {
                    self.eat_while(is_ws);
                    TokenKind::Whitespace
                }
                b'(' if self.peek(1) == b'*' => self.block_comment(b"(*", b"*)"),
                b'/' if self.peek(1) == b'*' => self.block_comment(b"/*", b"*/"),
                b'/' if self.peek(1) == b'/' => {
                    self.eat_while(|c| c != b'\n');
                    TokenKind::LineComment
                }
                b'{' => self.pragma(),
                b'\'' => self.string(false).0,
                b'"' => self.string(true).0,
                b'%' => self.direct_variable(),
                c if c.is_ascii_digit() => self.number(true),
                c if c.is_ascii_alphabetic() || c == b'_' => self.word(),
                _ => self.punct(),
            };
            self.push(kind, start);
        }
    }

    // ---- comments and pragmas -------------------------------------------

    /// [lexical.comment.block], [lexical.comment.cblock], nesting, unterminated.
    fn block_comment(&mut self, open: &[u8; 2], close: &[u8; 2]) -> TokenKind {
        let start = self.pos;
        self.pos += 2;
        loop {
            if self.at_end() {
                self.diag(
                    codes::UNTERMINATED_COMMENT,
                    "block comment is never closed",
                    start,
                    start + 2,
                );
                return TokenKind::BlockComment;
            }
            let pair = [self.b[self.pos], self.peek(1)];
            if &pair == close {
                self.pos += 2;
                return TokenKind::BlockComment;
            }
            if &pair == open {
                let at = self.pos;
                self.out.diagnostics.push(
                    Diagnostic::new(
                        codes::NESTED_COMMENT,
                        "comment opener inside a comment; comments do not nest",
                        Span::new(at, at + 2),
                    )
                    .with_hint("the comment ends at the first closer"),
                );
                self.pos += 2;
                continue;
            }
            self.pos += 1;
        }
    }

    /// [lexical.pragma]
    fn pragma(&mut self) -> TokenKind {
        let start = self.pos;
        self.pos += 1;
        self.eat_while(|c| c != b'}');
        if self.at_end() {
            self.diag(
                codes::UNTERMINATED_PRAGMA,
                "pragma is never closed with '}'",
                start,
                start + 1,
            );
            return TokenKind::Pragma;
        }
        self.pos += 1;
        let src = self.src;
        let inner = src[start + 1..self.pos - 1].trim_start();
        let name: String = inner
            .chars()
            .take_while(|c| c.is_ascii_alphanumeric() || *c == '_')
            .collect();
        if !is_known_pragma(&name) {
            self.diag(
                codes::UNKNOWN_PRAGMA,
                format!("unknown pragma '{name}' is ignored"),
                start,
                self.pos,
            );
        }
        TokenKind::Pragma
    }

    // ---- strings ----------------------------------------------------------

    /// [lexical.literal.string], [lexical.literal.escape], [lexical.literal.string.latin1].
    /// Returns the kind and the number of characters in the literal.
    fn string(&mut self, wide: bool) -> (TokenKind, usize) {
        let start = self.pos;
        let quote = self.b[self.pos];
        self.pos += 1;
        let (mut count, mut non_latin1) = (0usize, false);
        loop {
            if self.at_end() || matches!(self.b[self.pos], b'\n' | b'\r') {
                self.diag(
                    codes::UNTERMINATED_STRING,
                    "string literal is not closed on this line",
                    start,
                    self.pos,
                );
                break;
            }
            let c = self.b[self.pos];
            if c == quote {
                self.pos += 1;
                break;
            }
            count += 1;
            if c == b'$' {
                self.escape(wide);
                continue;
            }
            let len = self.char_len();
            if !wide
                && self.src[self.pos..]
                    .chars()
                    .next()
                    .is_some_and(|ch| ch as u32 > 0xff)
            {
                non_latin1 = true;
            }
            self.pos += len;
        }
        if non_latin1 {
            self.out.diagnostics.push(
                Diagnostic::new(
                    codes::NON_LATIN1_IN_STRING,
                    "STRING literal contains a character outside Latin-1",
                    Span::new(start, self.pos),
                )
                .with_hint("use a WSTRING literal in double quotes"),
            );
        }
        (
            if wide {
                TokenKind::WString
            } else {
                TokenKind::String
            },
            count,
        )
    }

    fn escape(&mut self, wide: bool) {
        let at = self.pos;
        let e = self.peek(1);
        if matches!(
            e.to_ascii_lowercase(),
            b'$' | b'\'' | b'"' | b'l' | b'n' | b'p' | b'r' | b't'
        ) {
            self.pos += 2;
            return;
        }
        let n = if wide { 4 } else { 2 };
        if (1..=n).all(|i| self.peek(i).is_ascii_hexdigit()) {
            self.pos += 1 + n;
            return;
        }
        // Unknown escape: consume `$` and the next char unless it ends the line.
        self.pos += 1;
        if !self.at_end() && !matches!(e, b'\n' | b'\r') {
            self.pos += self.char_len();
        }
        self.diag(
            codes::UNKNOWN_ESCAPE,
            "unknown escape sequence",
            at,
            self.pos,
        );
    }

    // ---- numbers ----------------------------------------------------------

    /// [lexical.literal.underscore]: `_` only between two digits.
    fn check_underscores(&mut self, a: usize, b: usize) {
        let t = &self.src[a..b];
        if t.starts_with('_') || t.ends_with('_') || t.contains("__") {
            self.out.diagnostics.push(
                Diagnostic::new(
                    codes::MISPLACED_UNDERSCORE,
                    "'_' in a number must stand between two digits",
                    Span::new(a, b),
                )
                .with_hint("remove the extra underscore"),
            );
        }
    }

    /// [lexical.literal.integer], [lexical.literal.real].
    fn number(&mut self, allow_based: bool) -> TokenKind {
        let start = self.pos;
        self.eat_while(|c| c.is_ascii_digit() || c == b'_');
        self.check_underscores(start, self.pos);

        if allow_based && self.peek(0) == b'#' {
            let base_txt: String = self.src[start..self.pos]
                .chars()
                .filter(|c| *c != '_')
                .collect();
            self.pos += 1;
            let ds = self.pos;
            self.eat_while(is_ident_char);
            let digits = &self.src[ds..self.pos];
            let radix = match base_txt.as_str() {
                "2" => 2,
                "8" => 8,
                "16" => 16,
                _ => 0,
            };
            let ok = radix != 0
                && digits.chars().any(|c| c != '_')
                && digits.chars().all(|c| c == '_' || c.is_digit(radix));
            if ok {
                self.check_underscores(ds, self.pos);
            } else {
                self.diag(
                    codes::MALFORMED_LITERAL,
                    "invalid based integer literal",
                    start,
                    self.pos,
                );
            }
            return TokenKind::Integer;
        }

        let mut kind = TokenKind::Integer;
        if self.peek(0) == b'.' && self.peek(1).is_ascii_digit() {
            self.pos += 1;
            let fs = self.pos;
            self.eat_while(|c| c.is_ascii_digit() || c == b'_');
            self.check_underscores(fs, self.pos);
            kind = TokenKind::Real;
        } else if self.peek(0) == b'.' && self.peek(1) != b'.' {
            self.pos += 1;
            self.diag(
                codes::MALFORMED_LITERAL,
                "real literal needs digits after the point",
                start,
                self.pos,
            );
            return TokenKind::Real;
        }

        if matches!(self.peek(0), b'e' | b'E') {
            let sign = usize::from(matches!(self.peek(1), b'+' | b'-'));
            if self.peek(1 + sign).is_ascii_digit() {
                self.pos += 1 + sign;
                let es = self.pos;
                self.eat_while(|c| c.is_ascii_digit() || c == b'_');
                self.check_underscores(es, self.pos);
                if kind == TokenKind::Integer {
                    // [lexical.literal.real]: accepted, but not portable.
                    self.diag(
                        codes::REAL_WITHOUT_POINT,
                        "real literal without a decimal point is not portable; write it as 1.0E-6",
                        start,
                        self.pos,
                    );
                }
                kind = TokenKind::Real;
            }
        }
        kind
    }

    // ---- identifiers and prefixed literals --------------------------------

    /// [lexical.identifier], [lexical.identifier.underscore], keywords.
    fn word(&mut self) -> TokenKind {
        let start = self.pos;
        self.eat_while(is_ident_char);
        let src = self.src;
        let word = &src[start..self.pos];
        if self.peek(0) == b'#' {
            return self.prefixed(start, word);
        }
        if word.contains("__") {
            self.diag(
                codes::DOUBLE_UNDERSCORE,
                "consecutive underscores in identifier",
                start,
                self.pos,
            );
        }
        if is_keyword(word) && !is_soft_keyword(word) {
            TokenKind::Keyword
        } else if is_elementary_type(word) {
            TokenKind::TypeName
        } else {
            TokenKind::Ident
        }
    }

    /// `PREFIX#...`: typed, duration, date/time, char and enum literals.
    fn prefixed(&mut self, start: usize, word: &str) -> TokenKind {
        let upper = word.to_ascii_uppercase();
        self.pos += 1; // '#'
        match upper.as_str() {
            "T" | "TIME" | "LT" | "LTIME" => self.duration(start),
            "D" | "DATE" | "LD" | "LDATE" => self.datetime(
                start,
                |c| c.is_ascii_digit() || c == b'-',
                validate_date,
                TokenKind::Date,
            ),
            "TOD" | "TIME_OF_DAY" | "LTOD" | "LTIME_OF_DAY" => self.datetime(
                start,
                |c| c.is_ascii_digit() || c == b':' || c == b'.',
                validate_tod,
                TokenKind::TimeOfDay,
            ),
            "DT" | "DATE_AND_TIME" | "LDT" | "LDATE_AND_TIME" => self.datetime(
                start,
                |c| c.is_ascii_digit() || matches!(c, b'-' | b':' | b'.'),
                validate_dt,
                TokenKind::DateAndTime,
            ),
            "CHAR" | "WCHAR" | "STRING" | "WSTRING" => {
                let wide = upper.starts_with('W');
                let quote = if wide { b'"' } else { b'\'' };
                if self.peek(0) != quote {
                    self.diag(
                        codes::MALFORMED_LITERAL,
                        format!("{upper}# must be followed by a quoted literal"),
                        start,
                        self.pos,
                    );
                    return TokenKind::Error;
                }
                let (_, count) = self.string(wide);
                if upper.ends_with("CHAR") {
                    if count != 1 {
                        self.diag(
                            codes::MALFORMED_LITERAL,
                            "character literal must hold exactly one character",
                            start,
                            self.pos,
                        );
                    }
                    TokenKind::Char
                } else {
                    TokenKind::TypedLiteral
                }
            }
            _ if is_elementary_type(&upper) => {
                if matches!(self.peek(0), b'+' | b'-') {
                    self.pos += 1;
                }
                match self.peek(0) {
                    c if c.is_ascii_digit() => {
                        self.number(true);
                    }
                    c if c.is_ascii_alphabetic() => self.eat_while(is_ident_char), // BOOL#TRUE
                    _ => self.diag(
                        codes::MALFORMED_LITERAL,
                        format!("{upper}# must be followed by a literal"),
                        start,
                        self.pos,
                    ),
                }
                TokenKind::TypedLiteral
            }
            _ => {
                let c = self.peek(0);
                if c.is_ascii_alphabetic() || c == b'_' {
                    self.eat_while(is_ident_char);
                    return TokenKind::EnumLiteral;
                }
                self.diag(
                    codes::UNKNOWN_LITERAL_TYPE,
                    format!("unknown type '{word}' in typed literal"),
                    start,
                    start + word.len(),
                );
                if matches!(c, b'+' | b'-') {
                    self.pos += 1;
                }
                match self.peek(0) {
                    c if c.is_ascii_digit() => {
                        self.number(true);
                    }
                    b'\'' => {
                        self.string(false);
                    }
                    b'"' => {
                        self.string(true);
                    }
                    _ => {}
                }
                TokenKind::Error
            }
        }
    }

    /// [lexical.literal.duration]
    fn duration(&mut self, start: usize) -> TokenKind {
        if self.peek(0) == b'-' {
            self.pos += 1;
        }
        let body_start = self.pos;
        self.eat_while(|c| is_ident_char(c) || c == b'.');
        if !validate_duration(&self.src[body_start..self.pos]) {
            self.diag(
                codes::MALFORMED_TIME_LITERAL,
                "malformed duration literal",
                start,
                self.pos,
            );
        }
        TokenKind::Duration
    }

    /// [lexical.literal.date]
    fn datetime(
        &mut self,
        start: usize,
        accept: impl Fn(u8) -> bool,
        validate: fn(&str) -> Result<(), DateError>,
        kind: TokenKind,
    ) -> TokenKind {
        let body_start = self.pos;
        self.eat_while(accept);
        match validate(&self.src[body_start..self.pos]) {
            Ok(()) => {}
            Err(DateError::Malformed) => self.diag(
                codes::MALFORMED_TIME_LITERAL,
                "malformed date/time literal",
                start,
                self.pos,
            ),
            Err(DateError::OutOfRange) => self.diag(
                codes::TIME_VALUE_OUT_OF_RANGE,
                "date/time value out of range",
                start,
                self.pos,
            ),
        }
        kind
    }

    /// [lexical.direct-variable]
    fn direct_variable(&mut self) -> TokenKind {
        let start = self.pos;
        self.pos += 1;
        self.eat_while(|c| c.is_ascii_alphabetic());
        let letters = self.src[start + 1..self.pos].to_ascii_uppercase();
        let addr_start = self.pos;
        if self.peek(0) == b'*' {
            self.pos += 1;
        } else {
            self.eat_while(|c| c.is_ascii_digit() || c == b'.');
        }
        let addr = &self.src[addr_start..self.pos];
        let mut l = letters.chars();
        let location_ok = matches!(l.next(), Some('I' | 'Q' | 'M'));
        let size_ok = match (l.next(), l.next()) {
            (None, _) => true,
            (Some(s), None) => matches!(s, 'X' | 'B' | 'W' | 'D' | 'L'),
            _ => false,
        };
        let addr_ok = addr == "*"
            || (!addr.is_empty()
                && addr
                    .split('.')
                    .all(|p| !p.is_empty() && p.bytes().all(|c| c.is_ascii_digit())));
        if !(location_ok && size_ok && addr_ok) {
            self.diag(
                codes::MALFORMED_DIRECT_VARIABLE,
                "malformed directly represented variable",
                start,
                self.pos,
            );
        }
        TokenKind::DirectVariable
    }

    // ---- punctuation and invalid text ----------------------------------------

    /// [lexical.punctuation], [lexical.longest-match]
    fn punct(&mut self) -> TokenKind {
        use TokenKind as T;
        let two = match (self.b[self.pos], self.peek(1)) {
            (b':', b'=') => Some(T::Assign),
            (b'=', b'>') => Some(T::Arrow),
            (b'?', b'=') => Some(T::AssignAttempt),
            (b'.', b'.') => Some(T::DotDot),
            (b'*', b'*') => Some(T::Power),
            (b'<', b'=') => Some(T::Le),
            (b'>', b'=') => Some(T::Ge),
            (b'<', b'>') => Some(T::Neq),
            _ => None,
        };
        if let Some(k) = two {
            self.pos += 2;
            return k;
        }
        let one = match self.b[self.pos] {
            b'(' => Some(T::LParen),
            b')' => Some(T::RParen),
            b'[' => Some(T::LBracket),
            b']' => Some(T::RBracket),
            b',' => Some(T::Comma),
            b';' => Some(T::Semicolon),
            b':' => Some(T::Colon),
            b'.' => Some(T::Dot),
            b'#' => Some(T::Hash),
            b'^' => Some(T::Caret),
            b'+' => Some(T::Plus),
            b'-' => Some(T::Minus),
            b'*' => Some(T::Star),
            b'/' => Some(T::Slash),
            b'&' => Some(T::Ampersand),
            b'=' => Some(T::Eq),
            b'<' => Some(T::Lt),
            b'>' => Some(T::Gt),
            _ => None,
        };
        if let Some(k) = one {
            self.pos += 1;
            return k;
        }
        self.invalid()
    }

    /// [lexical.source.charset]: a run of invalid characters is one error.
    fn invalid(&mut self) -> TokenKind {
        let start = self.pos;
        self.pos += self.char_len();
        while !self.at_end() && !self.starts_token() {
            self.pos += self.char_len();
        }
        self.diag(
            codes::INVALID_CHARACTER,
            format!("invalid character(s) '{}'", &self.src[start..self.pos]),
            start,
            self.pos,
        );
        TokenKind::Error
    }

    fn starts_token(&self) -> bool {
        let c = self.b[self.pos];
        is_ws(c)
            || is_ident_char(c)
            || b"()[],;:.#^+-*/&=<>{}'\"%".contains(&c)
            || (c == b'?' && self.peek(1) == b'=')
    }
}

fn digits_value(s: &str) -> Option<u64> {
    if s.is_empty() || !s.bytes().all(|c| c.is_ascii_digit()) {
        return None;
    }
    Some(s.parse::<u64>().unwrap_or(u64::MAX))
}

/// Validate the body of a duration literal (after `T#` and the optional `-`).
fn validate_duration(s: &str) -> bool {
    let b = s.as_bytes();
    let (mut i, mut last_unit, mut fields, mut prev_fraction) = (0usize, None::<usize>, 0, false);
    while i < b.len() {
        if fields > 0 && b[i] == b'_' {
            i += 1;
        }
        let ns = i;
        while i < b.len()
            && (b[i].is_ascii_digit()
                || (b[i] == b'_' && i > ns && i + 1 < b.len() && b[i + 1].is_ascii_digit()))
        {
            i += 1;
        }
        let int_part: String = s[ns..i].chars().filter(|c| *c != '_').collect();
        let Some(value) = digits_value(&int_part) else {
            return false;
        };
        let mut fraction = false;
        if i < b.len() && b[i] == b'.' {
            i += 1;
            let fs = i;
            while i < b.len() && b[i].is_ascii_digit() {
                i += 1;
            }
            if i == fs {
                return false;
            }
            fraction = true;
        }
        let us = i;
        while i < b.len() && b[i].is_ascii_alphabetic() {
            i += 1;
        }
        let unit = s[us..i].to_ascii_lowercase();
        let Some(idx) = DURATION_UNITS.iter().position(|(u, _)| *u == unit) else {
            return false;
        };
        if last_unit.is_some_and(|l| idx <= l) || prev_fraction {
            return false;
        }
        if fields > 0 && DURATION_UNITS[idx].1.is_some_and(|limit| value >= limit) {
            return false;
        }
        last_unit = Some(idx);
        prev_fraction = fraction;
        fields += 1;
    }
    fields > 0
}

#[derive(Debug, PartialEq, Eq)]
enum DateError {
    Malformed,
    OutOfRange,
}

fn validate_date(s: &str) -> Result<(), DateError> {
    let parts: Vec<&str> = s.split('-').collect();
    let [y, m, d] = parts.as_slice() else {
        return Err(DateError::Malformed);
    };
    let (y, m, d) = (
        digits_value(y).ok_or(DateError::Malformed)?,
        digits_value(m).ok_or(DateError::Malformed)?,
        digits_value(d).ok_or(DateError::Malformed)?,
    );
    let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
    let days = match m {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 if leap => 29,
        2 => 28,
        _ => return Err(DateError::OutOfRange),
    };
    if d == 0 || d > days {
        return Err(DateError::OutOfRange);
    }
    Ok(())
}

fn validate_tod(s: &str) -> Result<(), DateError> {
    let parts: Vec<&str> = s.split(':').collect();
    // hh:mm without seconds (CODESYS / TwinCAT) means hh:mm:00
    let (h, m, sec) = match parts.as_slice() {
        [h, m, sec] => (h, m, sec),
        [h, m] => (h, m, &"0"),
        _ => return Err(DateError::Malformed),
    };
    let (sec_int, frac) = match sec.split_once('.') {
        Some((i, f)) => (i, Some(f)),
        None => (*sec, None),
    };
    if frac.is_some_and(|f| digits_value(f).is_none()) {
        return Err(DateError::Malformed);
    }
    let (h, m, s) = (
        digits_value(h).ok_or(DateError::Malformed)?,
        digits_value(m).ok_or(DateError::Malformed)?,
        digits_value(sec_int).ok_or(DateError::Malformed)?,
    );
    if h >= 24 || m >= 60 || s >= 60 {
        return Err(DateError::OutOfRange);
    }
    Ok(())
}

fn validate_dt(s: &str) -> Result<(), DateError> {
    let mut it = s.splitn(4, '-');
    let (Some(y), Some(m), Some(d), Some(tod)) = (it.next(), it.next(), it.next(), it.next())
    else {
        return Err(DateError::Malformed);
    };
    // Report a malformed part before a range error in another part.
    let date = validate_date(&format!("{y}-{m}-{d}"));
    let time = validate_tod(tod);
    match (date, time) {
        (Err(DateError::Malformed), _) | (_, Err(DateError::Malformed)) => {
            Err(DateError::Malformed)
        }
        (Err(e), _) | (_, Err(e)) => Err(e),
        _ => Ok(()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn kinds(src: &str) -> Vec<TokenKind> {
        lex(src)
            .tokens
            .into_iter()
            .filter(|t| !t.kind.is_trivia())
            .map(|t| t.kind)
            .collect()
    }

    fn codes_of(src: &str) -> Vec<u16> {
        lex(src).diagnostics.iter().map(|d| d.code.0).collect()
    }

    #[test]
    fn lossless() {
        let src = "PROGRAM p (* c *) VAR x : INT := 16#FF; END_VAR x := x + 1; END_PROGRAM";
        let r = lex(src);
        let joined: String = r.tokens.iter().map(|t| t.text(src)).collect();
        assert_eq!(joined, src);
    }

    #[test]
    fn keywords_are_case_insensitive() {
        assert_eq!(
            kinds("end_if End_If"),
            [TokenKind::Keyword, TokenKind::Keyword]
        );
        assert_eq!(kinds("int Motor"), [TokenKind::TypeName, TokenKind::Ident]);
    }

    #[test]
    fn range_is_not_a_real() {
        use TokenKind as T;
        assert_eq!(kinds("1..10"), [T::Integer, T::DotDot, T::Integer]);
        assert_eq!(kinds("a.b"), [T::Ident, T::Dot, T::Ident]);
    }

    #[test]
    fn numbers() {
        assert_eq!(kinds("1.5E3"), [TokenKind::Real]);
        assert!(codes_of("2#1010_0101 16#ff 8#17 1_000").is_empty());
        assert_eq!(codes_of("1E3"), [17]); // accepted with a portability warning
        assert_eq!(codes_of("1__0"), [7]);
        assert_eq!(codes_of("3#12"), [8]);
    }

    #[test]
    fn durations() {
        for ok in [
            "T#1h_30m",
            "T#90m",
            "T#1.5s",
            "LTIME#5us",
            "t#-250ms",
            "T#1d2h3m4s5ms",
        ] {
            assert!(codes_of(ok).is_empty(), "{ok}");
        }
        for bad in ["T#5s1m", "T#1h90m", "T#1.5s20ms", "T#", "T#5x"] {
            assert_eq!(codes_of(bad), [11], "{bad}");
        }
    }

    #[test]
    fn dates() {
        assert!(codes_of("D#2024-02-29 TOD#23:59:59.999 DT#2026-11-03-14:30:00").is_empty());
        assert_eq!(codes_of("D#2026-02-29"), [12]);
        assert_eq!(codes_of("D#2026-11"), [11]);
        assert_eq!(codes_of("DT#2026-13-01-00:00:00"), [12]);
    }

    #[test]
    fn typed_and_enum_literals() {
        use TokenKind as T;
        assert_eq!(
            kinds("INT#-5 BOOL#TRUE Mode#Auto CHAR#'a'"),
            [T::TypedLiteral, T::TypedLiteral, T::EnumLiteral, T::Char]
        );
        assert_eq!(codes_of("FOO#5"), [14]);
    }

    #[test]
    fn strings() {
        assert!(codes_of("'it$'s $$5$N' \"say $\"hi$\"\" '$41' \"$00e9\"").is_empty());
        assert_eq!(codes_of("'a$Qb'"), [10]);
        assert_eq!(codes_of("'abc\nx"), [2]);
        assert_eq!(codes_of("'\u{6e29}'"), [9]);
        assert!(codes_of("'caf\u{e9}'").is_empty());
    }

    #[test]
    fn invalid_run_is_one_error() {
        assert_eq!(codes_of("x \u{6e29}\u{5ea6} @@ y"), [5, 5]);
    }

    #[test]
    fn direct_variables() {
        assert!(codes_of("%IX0.0 %QW4 %MD12 %I*").is_empty());
        assert_eq!(codes_of("%IZ0"), [16]);
        assert_eq!(codes_of("%QX1."), [16]);
    }
}
