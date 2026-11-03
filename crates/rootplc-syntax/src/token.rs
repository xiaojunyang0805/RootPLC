//! Token kinds and the reserved-word tables (spec/01-lexical.md).

use rootplc_diag::Span;

/// Kind of a token. The lexer is lossless: trivia (whitespace, comments,
/// pragmas) and invalid text are tokens too, so the tokens of a file
/// concatenate back to the exact source.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TokenKind {
    /// Spaces, tabs, line ends, form feeds, and a leading byte-order mark.
    Whitespace,
    /// `// ...`
    LineComment,
    /// `(* ... *)` or `/* ... */`
    BlockComment,
    /// `{ ... }`
    Pragma,
    /// An identifier that is not reserved.
    Ident,
    /// A keyword from [`KEYWORDS`].
    Keyword,
    /// An elementary type name from [`ELEMENTARY_TYPES`].
    TypeName,
    /// `42`, `16#FF`
    Integer,
    /// `1.5E3`
    Real,
    /// `INT#5`, `BOOL#TRUE`, `STRING#'abc'`
    TypedLiteral,
    /// `T#1h30m`, `LTIME#5us`
    Duration,
    /// `D#2026-11-03`
    Date,
    /// `TOD#14:30:00`
    TimeOfDay,
    /// `DT#2026-11-03-14:30:00`
    DateAndTime,
    /// `CHAR#'a'`, `WCHAR#"a"`
    Char,
    /// `'...'`
    String,
    /// `"..."`
    WString,
    /// `Mode#Auto`
    EnumLiteral,
    /// `%IX0.0`, `%QW4`, `%I*`
    DirectVariable,
    /// `:=`
    Assign,
    /// `=>`
    Arrow,
    /// `?=`
    AssignAttempt,
    /// `(`
    LParen,
    /// `)`
    RParen,
    /// `[`
    LBracket,
    /// `]`
    RBracket,
    /// `,`
    Comma,
    /// `;`
    Semicolon,
    /// `:`
    Colon,
    /// `.`
    Dot,
    /// `..`
    DotDot,
    /// `#`
    Hash,
    /// `^`
    Caret,
    /// `+`
    Plus,
    /// `-`
    Minus,
    /// `*`
    Star,
    /// `/`
    Slash,
    /// `**`
    Power,
    /// `&`
    Ampersand,
    /// `=`
    Eq,
    /// `<>`
    Neq,
    /// `<`
    Lt,
    /// `>`
    Gt,
    /// `<=`
    Le,
    /// `>=`
    Ge,
    /// Text that forms no token. Always paired with a diagnostic.
    Error,
}

impl TokenKind {
    /// Trivia carries no meaning for the parser.
    pub fn is_trivia(self) -> bool {
        matches!(
            self,
            TokenKind::Whitespace | TokenKind::LineComment | TokenKind::BlockComment
        )
    }
}

/// One token: its kind and where it is in the source.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Token {
    /// Kind.
    pub kind: TokenKind,
    /// Byte range in the source.
    pub span: Span,
}

impl Token {
    /// The token's text.
    pub fn text<'a>(&self, source: &'a str) -> &'a str {
        &source[self.span.start as usize..self.span.end as usize]
    }
}

/// Reserved keywords, [lexical.keyword].
pub const KEYWORDS: &[&str] = &[
    "ABSTRACT",
    "ACTION",
    "AND",
    "AND_THEN",
    "ARRAY",
    "AT",
    "BY",
    "CASE",
    "CLASS",
    "CONFIGURATION",
    "CONSTANT",
    "CONTINUE",
    "DO",
    "ELSE",
    "ELSIF",
    "END_ACTION",
    "END_CASE",
    "END_CLASS",
    "END_CONFIGURATION",
    "END_FOR",
    "END_FUNCTION",
    "END_FUNCTION_BLOCK",
    "END_IF",
    "END_INTERFACE",
    "END_METHOD",
    "END_NAMESPACE",
    "END_PROGRAM",
    "END_REPEAT",
    "END_RESOURCE",
    "END_STEP",
    "END_STRUCT",
    "END_TEST",
    "END_TRANSITION",
    "END_TYPE",
    "END_VAR",
    "END_WHILE",
    "EXIT",
    "EXTENDS",
    "FALSE",
    "FINAL",
    "FOR",
    "FROM",
    "FUNCTION",
    "FUNCTION_BLOCK",
    "IF",
    "IMPLEMENTS",
    "INITIAL_STEP",
    "INTERFACE",
    "INTERNAL",
    "METHOD",
    "MOD",
    "NAMESPACE",
    "NON_RETAIN",
    "NOT",
    "NULL",
    "OF",
    "ON",
    "OR",
    "OR_ELSE",
    "OVERLAP",
    "OVERRIDE",
    "PRIVATE",
    "PROGRAM",
    "PROTECTED",
    "PUBLIC",
    "READ_ONLY",
    "READ_WRITE",
    "REF",
    "REF_TO",
    "REPEAT",
    "RESOURCE",
    "RETAIN",
    "RETURN",
    "STEP",
    "STRUCT",
    "SUPER",
    "TASK",
    "TEST",
    "THEN",
    "THIS",
    "TO",
    "TRANSITION",
    "TRUE",
    "TYPE",
    "UNTIL",
    "USING",
    "VAR",
    "VAR_ACCESS",
    "VAR_CONFIG",
    "VAR_EXTERNAL",
    "VAR_GLOBAL",
    "VAR_INPUT",
    "VAR_IN_OUT",
    "VAR_OUTPUT",
    "VAR_STAT",
    "VAR_TEMP",
    "WHILE",
    "WITH",
    "XOR",
];

/// Elementary type names, [types.elementary]. Also reserved.
pub const ELEMENTARY_TYPES: &[&str] = &[
    "BOOL",
    "SINT",
    "INT",
    "DINT",
    "LINT",
    "USINT",
    "UINT",
    "UDINT",
    "ULINT",
    "REAL",
    "LREAL",
    "BYTE",
    "WORD",
    "DWORD",
    "LWORD",
    "TIME",
    "LTIME",
    "DATE",
    "LDATE",
    "TIME_OF_DAY",
    "TOD",
    "LTIME_OF_DAY",
    "LTOD",
    "DATE_AND_TIME",
    "DT",
    "LDATE_AND_TIME",
    "LDT",
    "CHAR",
    "WCHAR",
    "STRING",
    "WSTRING",
];

/// Pragmas RootPLC defines (spec/09-properties.md). Others give RP0013.
pub const KNOWN_PRAGMAS: &[&str] = &["attribute"];

fn contains_ci(list: &[&str], word: &str) -> bool {
    list.iter().any(|k| k.eq_ignore_ascii_case(word))
}

/// Is `word` a keyword? Case-insensitive, [lexical.identifier.case].
pub fn is_keyword(word: &str) -> bool {
    contains_ci(KEYWORDS, word)
}

/// Reserved words that RootPLC reads as names where no construct of theirs
/// can start ([lexical.keywords.soft]): SFC (not parsed) and configuration
/// words, common names in CODESYS / TwinCAT code. Declaring one as a name is
/// warning RP0124.
pub const SOFT_KEYWORDS: &[&str] = &[
    "STEP",
    "TRANSITION",
    "INITIAL_STEP",
    "TASK",
    "ON",
    "WITH",
    "AT",
];

/// Is `word` a soft keyword ([`SOFT_KEYWORDS`])? Case-insensitive.
pub fn is_soft_keyword(word: &str) -> bool {
    contains_ci(SOFT_KEYWORDS, word)
}

/// Is `word` an elementary type name? Case-insensitive.
pub fn is_elementary_type(word: &str) -> bool {
    contains_ci(ELEMENTARY_TYPES, word)
}

/// Is `word` a pragma name RootPLC defines?
pub fn is_known_pragma(word: &str) -> bool {
    contains_ci(KNOWN_PRAGMAS, word)
}
