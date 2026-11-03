//! Diagnostics: stable codes, severities, fix hints, JSON output and `explain` texts.
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`. The code list in [`codes`] must
//! match `spec/diagnostics.toml`; `rootplc-conformance` checks this.

/// Severity of a diagnostic.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Severity {
    /// Compilation cannot succeed.
    Error,
    /// Likely a bug, but the program compiles.
    Warning,
    /// Informational note.
    Note,
}

impl Severity {
    /// Lower-case name, as used in `spec/diagnostics.toml` and JSON output.
    pub fn as_str(self) -> &'static str {
        match self {
            Severity::Error => "error",
            Severity::Warning => "warning",
            Severity::Note => "note",
        }
    }
}

/// A stable diagnostic code such as `RP0001`. Codes are never reused or renumbered.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord)]
pub struct Code(pub u16);

impl core::fmt::Display for Code {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        write!(f, "RP{:04}", self.0)
    }
}

/// Byte range in a source file.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Span {
    /// Start offset (inclusive).
    pub start: u32,
    /// End offset (exclusive).
    pub end: u32,
}

impl Span {
    /// Span from byte offsets. Offsets beyond `u32::MAX` saturate.
    pub fn new(start: usize, end: usize) -> Span {
        let conv = |x: usize| u32::try_from(x).unwrap_or(u32::MAX);
        Span {
            start: conv(start),
            end: conv(end),
        }
    }
}

/// One diagnostic reported to a human or an agent.
#[derive(Debug, Clone)]
pub struct Diagnostic {
    /// Stable code.
    pub code: Code,
    /// Severity.
    pub severity: Severity,
    /// One-line message.
    pub message: String,
    /// Location in the source.
    pub span: Span,
    /// Optional fix hint.
    pub hint: Option<String>,
}

impl Diagnostic {
    /// Create a diagnostic; the severity comes from the code table.
    pub fn new(code: Code, message: impl Into<String>, span: Span) -> Diagnostic {
        Diagnostic {
            code,
            severity: codes::severity(code).unwrap_or(Severity::Error),
            message: message.into(),
            span,
            hint: None,
        }
    }

    /// Attach a fix hint.
    pub fn with_hint(mut self, hint: impl Into<String>) -> Diagnostic {
        self.hint = Some(hint.into());
        self
    }
}

/// The diagnostic code table. Mirrors `spec/diagnostics.toml`.
pub mod codes {
    use super::{Code, Severity};

    macro_rules! codes {
        ($($name:ident = $num:literal, $sev:ident;)*) => {
            $(
                #[doc = concat!("RP", stringify!($num))]
                pub const $name: Code = Code($num);
            )*
            /// Every code with its severity.
            pub const ALL: &[(Code, Severity)] = &[$(($name, Severity::$sev)),*];
        };
    }

    codes! {
        UNTERMINATED_COMMENT = 1, Error;
        UNTERMINATED_STRING = 2, Error;
        NESTED_COMMENT = 3, Warning;
        KEYWORD_AS_IDENTIFIER = 4, Error;
        INVALID_CHARACTER = 5, Error;
        DOUBLE_UNDERSCORE = 6, Warning;
        MISPLACED_UNDERSCORE = 7, Error;
        MALFORMED_LITERAL = 8, Error;
        NON_LATIN1_IN_STRING = 9, Error;
        UNKNOWN_ESCAPE = 10, Error;
        MALFORMED_TIME_LITERAL = 11, Error;
        TIME_VALUE_OUT_OF_RANGE = 12, Error;
        UNKNOWN_PRAGMA = 13, Warning;
        UNKNOWN_LITERAL_TYPE = 14, Error;
        UNTERMINATED_PRAGMA = 15, Error;
        MALFORMED_DIRECT_VARIABLE = 16, Error;
        SYNTAX_ERROR = 201, Error;
        MISSING_END = 202, Error;
        MISSING_SEMICOLON = 301, Error;
        CONSTANT_OVERFLOW = 101, Error;
        LITERAL_OUT_OF_RANGE = 102, Error;
        IMPLICIT_CONVERSION = 103, Error;
        GENERIC_TYPE_IN_DECLARATION = 104, Error;
        OUTSIDE_SUBRANGE = 105, Error;
        AMBIGUOUS_ENUM_VALUE = 106, Error;
        RECURSIVE_STRUCT = 107, Error;
        INVALID_BOUNDS = 108, Error;
        CONSTANT_INDEX_OUT_OF_BOUNDS = 109, Error;
        STRING_LITERAL_TOO_LONG = 110, Warning;
        UNKNOWN_TYPE = 111, Error;
    }

    /// Severity of a code, if the code exists.
    pub fn severity(code: Code) -> Option<Severity> {
        ALL.iter().find(|(c, _)| *c == code).map(|(_, s)| *s)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn code_formats_with_prefix() {
        assert_eq!(Code(7).to_string(), "RP0007");
    }

    #[test]
    fn severity_comes_from_table() {
        let d = Diagnostic::new(codes::NESTED_COMMENT, "x", Span::new(0, 1));
        assert_eq!(d.severity, Severity::Warning);
    }
}
