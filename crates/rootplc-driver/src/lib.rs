//! Project model (`rootplc.toml`) and the implementation of every `rootplc` command. The CLI and MCP server call only this crate.
//!
//! Roadmap phase: 1. See `ARCHITECTURE.md`.

pub mod agents;
pub mod coverage;
pub mod docs;
pub mod examples;
pub mod explain;
pub mod init;
pub mod json;

use std::path::PathBuf;

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
    /// Search the verified pattern library.
    Examples,
    /// Classify units as portable, dialect or blocked.
    Coverage,
    /// List the bundled compatibility libraries.
    Libraries,
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
        Command::Examples,
        Command::Coverage,
        Command::Libraries,
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
            Command::Examples => "examples",
            Command::Coverage => "coverage",
            Command::Libraries => "libraries",
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
    pub path: PathBuf,
    /// Source text.
    pub source: String,
    /// Lexer, parser and checker diagnostics.
    pub diagnostics: Vec<rootplc_diag::Diagnostic>,
    /// A file of an active compatibility library: checked with the project,
    /// never reported ([stdlib.compat]).
    pub library: bool,
}

/// Result of [`check`].
#[derive(Debug, Clone)]
pub struct CheckReport {
    /// Every file, in path order.
    pub files: Vec<CheckedFile>,
    /// The typed IR, when no file has an error.
    pub program: Option<rootplc_sema::ir::Program>,
    /// For each file index used by the IR and the VM, the index in `files`.
    pub ir_files: Vec<usize>,
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
            .filter(|f| !f.library)
            .flat_map(|f| &f.diagnostics)
            .filter(|d| d.severity == sev)
            .count()
    }
}

fn collect_st(path: &std::path::Path, out: &mut Vec<PathBuf>) -> std::io::Result<()> {
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

/// Read the `.st` files under `paths` (directories recursively).
pub fn read_sources(paths: &[PathBuf]) -> Result<Vec<(PathBuf, String)>, String> {
    let mut found = Vec::new();
    for p in paths {
        collect_st(p, &mut found).map_err(|e| format!("{}: {e}", p.display()))?;
    }
    found
        .into_iter()
        .map(|path| {
            let source =
                std::fs::read_to_string(&path).map_err(|e| format!("{}: {e}", path.display()))?;
            Ok((path, source))
        })
        .collect()
}

/// `rootplc check`: lex, parse and type-check `.st` files. Directories are
/// searched recursively. All files form one project, so names declared in one
/// file are visible in the others. Files with syntax errors are not
/// type-checked; the rest are.
pub fn check(paths: &[PathBuf]) -> Result<CheckReport, String> {
    Ok(check_sources(read_sources(paths)?))
}

/// [`check`] on sources held in memory (name, text), e.g. from an agent.
pub fn check_sources(sources: Vec<(PathBuf, String)>) -> CheckReport {
    check_files(sources, &[])
}

/// [`check_sources`] with compatibility libraries activated by name
/// ([stdlib.compat]). An unknown name is an error listing the known ones.
pub fn check_sources_with(
    sources: Vec<(PathBuf, String)>,
    libraries: &[String],
) -> Result<CheckReport, String> {
    let libs = rootplc_stdlib::compat::resolve(libraries).map_err(|name| {
        let known: Vec<String> = rootplc_stdlib::compat::libraries()
            .into_iter()
            .map(|l| l.name)
            .collect();
        format!(
            "unknown compatibility library '{name}'; bundled: {}",
            known.join(", ")
        )
    })?;
    Ok(check_files(sources, &libs))
}

fn check_files(
    sources: Vec<(PathBuf, String)>,
    libs: &[rootplc_stdlib::compat::Library],
) -> CheckReport {
    let mut files: Vec<CheckedFile> = sources
        .into_iter()
        .map(|(path, source)| CheckedFile {
            path,
            source,
            diagnostics: Vec::new(),
            library: false,
        })
        .collect();
    for l in libs {
        for (name, src) in &l.files {
            files.push(CheckedFile {
                path: PathBuf::from(format!("<{}>/{name}", l.name)),
                source: (*src).to_string(),
                diagnostics: Vec::new(),
                library: true,
            });
        }
    }
    let opts = rootplc_sema::Options {
        declare_only: libs.iter().flat_map(|l| l.declare_only.clone()).collect(),
        qualifiers: libs.iter().map(|l| l.name.clone()).collect(),
        intrinsics: libs.iter().flat_map(|l| l.intrinsics.clone()).collect(),
    };
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
    // Every file takes part in the analysis, so the declarations of a file
    // with a syntax error stay visible to the others (the parser recovers);
    // its own semantic diagnostics are left out, the syntax errors come first.
    let all: Vec<usize> = (0..files.len()).collect();
    let input: Vec<_> = all
        .iter()
        .map(|&i| (&parses[i], files[i].source.as_str()))
        .collect();
    let analysis = rootplc_sema::analyze_with(&input, &opts);
    for (&i, diags) in all.iter().zip(analysis.diagnostics) {
        if clean.contains(&i) {
            files[i].diagnostics.extend(diags);
        }
    }
    let mut report = CheckReport {
        files,
        program: None,
        ir_files: all,
    };
    if report.ok() {
        report.program = Some(analysis.program);
    }
    report
}

/// Result of [`test`].
#[derive(Debug, Clone)]
pub struct TestReport {
    /// Compilation result; tests run only when it has no errors.
    pub check: CheckReport,
    /// One outcome per TEST block.
    pub outcomes: Vec<rootplc_testing::TestOutcome>,
}

impl TestReport {
    /// Compiled and every test passed.
    pub fn ok(&self) -> bool {
        self.check.ok()
            && self
                .outcomes
                .iter()
                .all(rootplc_testing::TestOutcome::passed)
    }
}

/// `rootplc test`: compile, then run every TEST block ([tests.runner]).
pub fn test(paths: &[PathBuf], filter: Option<&str>) -> Result<TestReport, String> {
    Ok(test_report(check(paths)?, filter))
}

/// Run the TEST blocks of a compiled project.
pub fn test_report(check: CheckReport, filter: Option<&str>) -> TestReport {
    let outcomes = match &check.program {
        Some(p) => rootplc_testing::run_tests(p, filter),
        None => Vec::new(),
    };
    TestReport { check, outcomes }
}

/// Result of [`run`].
#[derive(Debug, Clone)]
pub struct RunReport {
    /// Compilation result.
    pub check: CheckReport,
    /// Program that ran.
    pub program: String,
    /// Cycles completed.
    pub cycles: u64,
    /// Fault that stopped the run.
    pub fault: Option<rootplc_vm::Fault>,
    /// Variables after the last cycle: name and IEC literal text.
    pub variables: Vec<(String, String)>,
}

impl RunReport {
    /// Compiled and ran without a fault.
    pub fn ok(&self) -> bool {
        self.check.ok() && self.fault.is_none()
    }
}

/// `rootplc run`: execute a PROGRAM for `cycles` cycles in the VM, advancing
/// the virtual clock by `cycle_ns` per cycle.
pub fn run(
    paths: &[PathBuf],
    program: Option<&str>,
    cycles: u64,
    cycle_ns: i128,
) -> Result<RunReport, String> {
    run_report(check(paths)?, program, cycles, cycle_ns)
}

/// Run a program of a compiled project.
pub fn run_report(
    check: CheckReport,
    program: Option<&str>,
    cycles: u64,
    cycle_ns: i128,
) -> Result<RunReport, String> {
    let Some(prog) = &check.program else {
        return Ok(RunReport {
            check,
            program: String::new(),
            cycles: 0,
            fault: None,
            variables: Vec::new(),
        });
    };
    let programs: Vec<usize> = (0..prog.defs.len())
        .filter(|&i| matches!(prog.pou(i), Some(p) if p.kind == rootplc_sema::ir::PouKind::Program))
        .collect();
    let def = match program {
        Some(name) => prog
            .find(name)
            .filter(|i| programs.contains(i))
            .ok_or_else(|| format!("no PROGRAM named '{name}'"))?,
        None => match programs.as_slice() {
            [one] => *one,
            [] => return Err("the project has no PROGRAM".into()),
            _ => return Err("the project has several programs; choose one with --program".into()),
        },
    };
    let mut vm = rootplc_vm::Vm::new(prog);
    let root = vm.instantiate(def);
    let (mut done, mut fault) = (0, None);
    for _ in 0..cycles {
        if let Err(f) = vm.cycle(root, def) {
            fault = Some(f);
            break;
        }
        done += 1;
        vm.advance(cycle_ns);
    }
    let pou = prog.pou(def).ok_or("not a POU")?;
    let variables = pou
        .vars
        .iter()
        .filter_map(|v| {
            vm.read_var(root, def, &v.name)
                .map(|x| (v.name.clone(), vm.display(x, &v.ty)))
        })
        .collect();
    let name = prog.defs[def].name.clone();
    Ok(RunReport {
        check,
        program: name,
        cycles: done,
        fault,
        variables,
    })
}
