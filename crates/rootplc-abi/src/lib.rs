//! Runtime ABI shared by codegen-c, the Rust runtime and the C shim: program image, I/O image, variable table, force masks.
//!
//! Roadmap phase: 2-3. See `ARCHITECTURE.md`.

/// ABI version. Bumped on any incompatible layout change.
pub const ABI_VERSION: u32 = 0;
