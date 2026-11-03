//! Clean-room IEC 61131-3 standard library, written in ST and embedded at build time.
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`.

/// One ST source file of the standard library.
pub struct StdFile {
    /// File name relative to `st/`.
    pub name: &'static str,
    /// ST source text.
    pub source: &'static str,
}

/// All standard-library sources.
pub const FILES: &[StdFile] = &[
    StdFile {
        name: "timers.st",
        source: include_str!("../st/timers.st"),
    },
    StdFile {
        name: "edges.st",
        source: include_str!("../st/edges.st"),
    },
];
