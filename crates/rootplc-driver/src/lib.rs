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

/// One checked file.
#[derive(Debug, Clone)]
pub struct CheckedFile {
    /// Path as given or found.
    pub path: std::path::PathBuf,
    /// Source text.
    pub source: String,
    /// Lexer, parser and checker diagnostics.
    pub diagnostics: Vec<rootplc_diag::Diagnostic>,
}

/// Result of [`check`].
#[derive(Debug, Clone)]
pub struct CheckReport {
    /// Every file, in path order.
    pub files: Vec<CheckedFile>,
}

impl CheckReport {
    /// True if no diagnostic is an error.
    pub fn ok(&self) -> bool {
        self.count(rootplc_diag::Severity::Error) == 0
    }

    /// Number of diagnostics of a severity.
    pub fn count(&self, sev: rootplc_diag::Severity) -> usize {
        self.files
            .iter()
            .flat_map(|f| &f.diagnostics)
            .filter(|d| d.severity == sev)
            .count()
    }
}

fn collect_st(path: &std::path::Path, out: &mut Vec<std::path::PathBuf>) -> std::io::Result<()> {
    if path.is_dir() {
        let mut entries: Vec<_> = std::fs::read_dir(path)?
            .map(|e| e.map(|e| e.path()))
            .collect::<Result<_, _>>()?;
        entries.sort();
        for p in entries {
            if p.is_dir() || p.extension().is_some_and(|e| e.eq_ignore_ascii_case("st")) {
                collect_st(&p, out)?;
            }
        }
    } else {
        out.push(path.to_path_buf());
    }
    Ok(())
}

/// `rootplc check`: lex, parse and type-check `.st` files. Directories are
/// searched recursively. All files form one project, so names declared in one
/// file are visible in the others. Files with syntax errors are not
/// type-checked; the rest are.
pub fn check(paths: &[std::path::PathBuf]) -> Result<CheckReport, String> {
    let mut found = Vec::new();
    for p in paths {
        collect_st(p, &mut found).map_err(|e| format!("{}: {e}", p.display()))?;
    }
    let mut files = Vec::new();
    for path in found {
        let source =
            std::fs::read_to_string(&path).map_err(|e| format!("{}: {e}", path.display()))?;
        files.push(CheckedFile {
            path,
            source,
            diagnostics: Vec::new(),
        });
    }
    let parses: Vec<_> = files
        .iter()
        .map(|f| rootplc_syntax::parse(&f.source))
        .collect();
    let mut clean = Vec::new();
    for (i, (f, p)) in files.iter_mut().zip(&parses).enumerate() {
        f.diagnostics.extend(p.lex_diagnostics.iter().cloned());
        f.diagnostics.extend(p.diagnostics.iter().cloned());
        if !f
            .diagnostics
            .iter()
            .any(|d| d.severity == rootplc_diag::Severity::Error)
        {
            clean.push(i);
        }
    }
    let input: Vec<_> = clean
        .iter()
        .map(|&i| (&parses[i], files[i].source.as_str()))
        .collect();
    let results = rootplc_sema::check_project(&input);
    for (&i, diags) in clean.iter().zip(results) {
        files[i].diagnostics.extend(diags);
    }
    Ok(CheckReport { files })
}
