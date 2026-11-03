//! Reference runtime on PREEMPT_RT Linux: scheduler, program loading, force/trace, online change, signed deploy, runtime agent API.
//!
//! Roadmap phase: 3. See `ARCHITECTURE.md`.

/// FFI and hardware access. The only place where `unsafe` may appear in this
/// crate; every block needs a `// SAFETY:` comment and a Kani proof or justification.
#[allow(unsafe_code)]
pub mod ffi {}
