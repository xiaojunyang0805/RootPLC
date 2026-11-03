//! Diagnostics: stable codes, severities, fix hints, JSON output and `explain` texts.
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`.

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

/// A stable diagnostic code such as `RP0001`. Codes are never reused or renumbered.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
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
    /// Optional machine-applicable fix hint.
    pub hint: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn code_formats_with_prefix() {
        assert_eq!(Code(7).to_string(), "RP0007");
    }
}
