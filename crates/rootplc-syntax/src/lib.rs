//! Lexer, parser and lossless syntax tree for Structured Text and the text forms of SFC/LD/FBD.
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`. Implemented so far: the lexer.

pub mod lexer;
pub mod token;

pub use lexer::{LexResult, lex, lex_bytes};
pub use token::{Token, TokenKind};
