//! Project model (`rootplc.toml`) and the implementation of every `rootplc` command. The CLI and MCP server call only this crate.
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`.

/// Every command the toolchain offers. CLI and MCP map onto this list one to one.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Command {
    /// Create a project with `rootplc.toml` and an AGENTS.md.
    Init,
    /// Parse and type-check.
    Check,
    /// Compile to bytecode or C.
    Build,
    /// Run TEST blocks.
    Test,
    /// Run the program in the VM.
    Run,
    /// Run a simulation scenario.
    Sim,
    /// Formal verification with CBMC.
    Verify,
    /// Explain a diagnostic code.
    Explain,
    /// Import PLCopen / TwinCAT XML.
    Import,
    /// Deploy to a runtime. Always requires human approval.
    Deploy,
    /// Read live values from a runtime.
    Monitor,
    /// Record a variable trace from a runtime.
    Trace,
}

impl Command {
    /// All commands, in help order.
    pub const ALL: &'static [Command] = &[
        Command::Init,
        Command::Check,
        Command::Build,
        Command::Test,
        Command::Run,
        Command::Sim,
        Command::Verify,
        Command::Explain,
        Command::Import,
        Command::Deploy,
        Command::Monitor,
        Command::Trace,
    ];

    /// Command name as typed on the command line.
    pub fn name(self) -> &'static str {
        match self {
            Command::Init => "init",
            Command::Check => "check",
            Command::Build => "build",
            Command::Test => "test",
            Command::Run => "run",
            Command::Sim => "sim",
            Command::Verify => "verify",
            Command::Explain => "explain",
            Command::Import => "import",
            Command::Deploy => "deploy",
            Command::Monitor => "monitor",
            Command::Trace => "trace",
        }
    }

    /// Look up a command by name.
    pub fn from_name(name: &str) -> Option<Command> {
        Command::ALL.iter().copied().find(|c| c.name() == name)
    }

    /// Commands that act on real hardware and need human approval.
    pub fn needs_approval(self) -> bool {
        matches!(self, Command::Deploy)
    }
}
