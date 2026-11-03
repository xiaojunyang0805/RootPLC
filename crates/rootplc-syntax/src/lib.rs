//! Lexer, parser and lossless syntax tree for Structured Text and the text forms of SFC/LD/FBD.
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`. Implemented: lexer and lossless parser with error recovery.

pub mod lexer;
pub mod parser;
pub mod token;
pub mod tree;

pub use lexer::{LexResult, lex, lex_bytes};
pub use parser::{Parse, parse};
pub use token::{Token, TokenKind};
pub use tree::{Element, Node, NodeKind};
