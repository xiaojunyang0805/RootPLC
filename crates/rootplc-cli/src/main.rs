//! The `rootplc` binary. Argument parsing and output formatting only;
//! every command is implemented in `rootplc-driver`.

use rootplc_diag::Severity;
use rootplc_driver::{CheckReport, Command, json};
use std::path::PathBuf;
use std::process::ExitCode;

const USAGE: &str = "usage:
  rootplc init  [dir] [--name NAME] [--agent claude|gemini|qwen|cursor|codex|all]
  rootplc check <file.st|dir>... [--json]
  rootplc test  <file.st|dir>... [--filter TEXT] [--json]
  rootplc run   <file.st|dir>... [--program NAME] [--cycles N] [--cycle-ms MS] [--json]
  rootplc explain <code> [--json]
  rootplc examples [words...] [--show ID] [--json]   (verified ST patterns)
  rootplc coverage <file.st|dir>... [--json]
  rootplc libraries [--json]                       (bundled compatibility libraries)
  check, test, run and coverage take --library NAME[,NAME] (e.g. Tc2_System)       (portable / dialect / dependent / blocked)
  rootplc mcp            (MCP server on stdio, for agent hosts)
  rootplc --version

exit codes: 0 ok, 1 errors / failed tests / fault, 2 usage or I/O error";

/// Parsed command line: positional arguments, flags and `--name value` options.
struct Args {
    positional: Vec<String>,
    json: bool,
    options: Vec<(String, String)>,
}

impl Args {
    fn parse() -> Args {
        let mut a = Args {
            positional: Vec::new(),
            json: false,
            options: Vec::new(),
        };
        let mut it = std::env::args().skip(1);
        while let Some(x) = it.next() {
            match x.as_str() {
                "--json" => a.json = true,
                "--program" | "--cycles" | "--cycle-ms" | "--filter" | "--name" | "--show"
                | "--agent" | "--library" => {
                    let v = it.next().unwrap_or_default();
                    a.options.push((x, v));
                }
                _ => a.positional.push(x),
            }
        }
        a
    }

    /// Every value of a repeatable option such as `--library`.
    fn all(&self, name: &str) -> Vec<String> {
        self.options
            .iter()
            .filter(|(k, _)| k == name)
            .map(|(_, v)| v.clone())
            .collect()
    }

    fn opt(&self, name: &str) -> Option<&str> {
        self.options
            .iter()
            .rev()
            .find(|(k, _)| k == name)
            .map(|(_, v)| v.as_str())
    }
}

fn exit(ok: bool) -> ExitCode {
    if ok {
        ExitCode::SUCCESS
    } else {
        ExitCode::from(1)
    }
}

fn io_error(cmd: &str, e: &str, json: bool) -> ExitCode {
    if json {
        println!("{}", json::error(cmd, e));
    } else {
        eprintln!("rootplc {cmd}: {e}");
    }
    ExitCode::from(2)
}

/// Read the sources and check them with the `--library` libraries.
fn load(cmd: &str, paths: &[PathBuf], args: &Args) -> Result<CheckReport, ExitCode> {
    let sources = rootplc_driver::read_sources(paths).map_err(|e| io_error(cmd, &e, args.json))?;
    rootplc_driver::check_sources_with(sources, &args.all("--library"))
        .map_err(|e| io_error(cmd, &e, args.json))
}

fn print_diagnostics(report: &CheckReport) {
    for f in report.files.iter().filter(|f| !f.library) {
        let name = f.path.display().to_string();
        for d in &f.diagnostics {
            println!("{}", d.render_text(&name, &f.source));
        }
    }
}

fn cmd_check(paths: &[PathBuf], args: &Args) -> ExitCode {
    let json_out = args.json;
    let r = match load("check", paths, args) {
        Ok(r) => r,
        Err(code) => return code,
    };
    if json_out {
        println!("{}", json::check(&r));
    } else {
        print_diagnostics(&r);
        eprintln!(
            "checked {} file(s): {} error(s), {} warning(s)",
            r.files.iter().filter(|f| !f.library).count(),
            r.count(Severity::Error),
            r.count(Severity::Warning)
        );
    }
    exit(r.ok())
}

fn cmd_test(paths: &[PathBuf], filter: Option<&str>, args: &Args) -> ExitCode {
    let json_out = args.json;
    let r = match load("test", paths, args) {
        Ok(c) => rootplc_driver::test_report(c, filter),
        Err(code) => return code,
    };
    if json_out {
        println!("{}", json::test(&r));
        return exit(r.ok());
    }
    print_diagnostics(&r.check);
    for o in &r.outcomes {
        println!("{} {}", if o.passed() { "PASS" } else { "FAIL" }, o.name);
        for f in &o.failures {
            let (n, l, c) = json::location(&r.check, f.file, f.span.start);
            println!("  {n}:{l}:{c}: {}", f.message);
        }
        if let Some(f) = &o.fault {
            let (n, l, c) = json::location(&r.check, f.file, f.span.start);
            println!("  {n}:{l}:{c}: fault {}: {}", f.kind.name(), f.message);
        }
    }
    let passed = r.outcomes.iter().filter(|o| o.passed()).count();
    if r.check.ok() {
        eprintln!("{passed} passed, {} failed", r.outcomes.len() - passed);
    } else {
        eprintln!("compilation failed; no tests were run");
    }
    exit(r.ok())
}

fn cmd_run(paths: &[PathBuf], args: &Args) -> ExitCode {
    let cycles = args
        .opt("--cycles")
        .and_then(|v| v.parse().ok())
        .unwrap_or(1);
    let cycle_ms: i128 = args
        .opt("--cycle-ms")
        .and_then(|v| v.parse().ok())
        .unwrap_or(10);
    let check = match load("run", paths, args) {
        Ok(c) => c,
        Err(code) => return code,
    };
    let r = match rootplc_driver::run_report(
        check,
        args.opt("--program"),
        cycles,
        cycle_ms * 1_000_000,
    ) {
        Ok(r) => r,
        Err(e) => return io_error("run", &e, args.json),
    };
    if args.json {
        println!("{}", json::run(&r));
        return exit(r.ok());
    }
    print_diagnostics(&r.check);
    if r.check.ok() {
        println!("{} after {} cycle(s):", r.program, r.cycles);
        for (n, v) in &r.variables {
            println!("  {n} = {v}");
        }
        if let Some(f) = &r.fault {
            let (n, l, c) = json::location(&r.check, f.file, f.span.start);
            println!("{n}:{l}:{c}: fault {}: {}", f.kind.name(), f.message);
        }
    }
    exit(r.ok())
}

fn cmd_explain(code: Option<&String>, json_out: bool) -> ExitCode {
    let Some(code) = code else {
        return io_error(
            "explain",
            "give a diagnostic code, e.g. rootplc explain RP0103",
            json_out,
        );
    };
    let Some(e) = rootplc_driver::explain::explain(code) else {
        return io_error(
            "explain",
            &format!("unknown diagnostic code '{code}'"),
            json_out,
        );
    };
    if json_out {
        println!("{}", json::explain(&e));
    } else {
        println!(
            "{} ({}): {}\n\nRule [{}] in {}:\n\n{}",
            e.code, e.severity, e.summary, e.rule, e.file, e.text
        );
    }
    ExitCode::SUCCESS
}

fn cmd_examples(words: &[String], args: &Args) -> ExitCode {
    use rootplc_driver::examples;
    if let Some(id) = args.opt("--show") {
        let Some(e) = examples::get(id) else {
            return io_error("examples", &format!("no example '{id}'"), args.json);
        };
        if args.json {
            println!("{}", json::examples(id, &[e], true));
        } else {
            print!("{}", e.source);
        }
        return ExitCode::SUCCESS;
    }
    let query = words.join(" ");
    let found = examples::search(&query);
    if args.json {
        println!("{}", json::examples(&query, &found, true));
        return ExitCode::SUCCESS;
    }
    for e in &found {
        println!(
            "{:<22} {}
{:<22} {}",
            e.id, e.title, "", e.description
        );
    }
    if found.is_empty() {
        eprintln!("no example matches '{query}'; run rootplc examples to list all");
    } else {
        eprintln!(
            "{} example(s); show one with rootplc examples --show <id>",
            found.len()
        );
    }
    exit(!found.is_empty())
}

fn cmd_coverage(paths: &[PathBuf], args: &Args) -> ExitCode {
    use rootplc_driver::coverage::Status;
    let json_out = args.json;
    let r = match rootplc_driver::read_sources(paths)
        .and_then(|s| rootplc_driver::coverage::coverage_sources_with(s, &args.all("--library")))
    {
        Ok(r) => r,
        Err(e) => return io_error("coverage", &e, json_out),
    };
    if json_out {
        println!("{}", json::coverage(&r));
        return ExitCode::SUCCESS;
    }
    for u in &r.units {
        let detail = if !u.blocked_by.is_empty() && u.constructs.is_empty() {
            let deps: Vec<String> = u
                .blocked_by
                .iter()
                .map(|p| p.display().to_string())
                .collect();
            format!("needs {}", deps.join(", "))
        } else if u.constructs.is_empty() {
            u.codes.join(" ")
        } else {
            u.constructs
                .iter()
                .map(|c| format!("{} (line {})", c.name, c.line))
                .collect::<Vec<_>>()
                .join(", ")
        };
        println!("{:<9} {}  {detail}", u.status.name(), u.path.display());
    }
    let n = r.units.len().max(1);
    eprintln!(
        "{} unit(s): {} portable ({}%), {} dialect, {} dependent, {} blocked",
        r.units.len(),
        r.count(Status::Portable),
        100 * r.count(Status::Portable) / n,
        r.count(Status::Dialect),
        r.count(Status::Dependent),
        r.count(Status::Blocked)
    );
    ExitCode::SUCCESS
}

fn cmd_libraries(json_out: bool) -> ExitCode {
    if json_out {
        println!("{}", json::libraries());
        return ExitCode::SUCCESS;
    }
    for l in rootplc_stdlib::compat::libraries() {
        println!(
            "{} {} ({})\n    {}",
            l.name, l.version, l.vendor, l.description
        );
        if !l.declare_only.is_empty() {
            println!("    declared only (not run): {}", l.declare_only.join(", "));
        }
    }
    eprintln!("activate with --library NAME; RootPLC is not affiliated with the vendors named");
    ExitCode::SUCCESS
}

fn cmd_init(dir: Option<&String>, name: Option<&str>, agent: Option<&str>) -> ExitCode {
    use rootplc_driver::agents::{Host, Outcome, configure};
    let dir = PathBuf::from(dir.map_or(".", String::as_str));
    let hosts = match agent.map(Host::parse_list).transpose() {
        Ok(h) => h,
        Err(e) => return io_error("init", &e, false),
    };
    // With --agent in an existing project, only the host files are added.
    let existing = hosts.is_some() && dir.join("rootplc.toml").exists();
    if !existing {
        match rootplc_driver::init::init(&dir, name) {
            Ok(created) => {
                for p in created {
                    println!("created {}", p.display());
                }
            }
            Err(e) => return io_error("init", &e, false),
        }
    }
    if let Some(hosts) = hosts {
        match configure(&dir, &hosts) {
            Ok(outcomes) => {
                for o in outcomes {
                    match o {
                        Outcome::Created(p) => println!("created {}", p.display()),
                        Outcome::AlreadyConfigured(p) => {
                            println!("kept    {} (already set up)", p.display());
                        }
                        Outcome::MergeByHand(p, snippet) => println!(
                            "exists  {}: not changed; add this yourself:\n{snippet}",
                            p.display()
                        ),
                    }
                }
            }
            Err(e) => return io_error("init", &e, false),
        }
    }
    println!(
        "next: rootplc check {d} && rootplc test {d}",
        d = dir.display()
    );
    ExitCode::SUCCESS
}

fn main() -> ExitCode {
    let args = Args::parse();
    if args
        .positional
        .iter()
        .any(|a| a == "--version" || a == "-V")
    {
        println!("rootplc {}", env!("CARGO_PKG_VERSION"));
        return ExitCode::SUCCESS;
    }
    if args.positional.iter().any(|a| a == "--help" || a == "-h") {
        println!("{USAGE}");
        return ExitCode::SUCCESS;
    }
    let Some(first) = args.positional.first() else {
        eprintln!("{USAGE}");
        return ExitCode::from(2);
    };
    let rest = &args.positional[1..];
    if first == "mcp" {
        return match rootplc_mcp::serve_stdio() {
            Ok(()) => ExitCode::SUCCESS,
            Err(e) => io_error("mcp", &e.to_string(), false),
        };
    }
    let cmd = Command::from_name(first);
    let paths: Vec<PathBuf> = rest.iter().map(PathBuf::from).collect();
    if matches!(
        cmd,
        Some(Command::Check | Command::Test | Command::Run | Command::Coverage)
    ) && paths.is_empty()
    {
        eprintln!("rootplc {first}: give one or more .st files or directories\n\n{USAGE}");
        return ExitCode::from(2);
    }
    match cmd {
        Some(Command::Check) => cmd_check(&paths, &args),
        Some(Command::Test) => cmd_test(&paths, args.opt("--filter"), &args),
        Some(Command::Libraries) => cmd_libraries(args.json),
        Some(Command::Run) => cmd_run(&paths, &args),
        Some(Command::Explain) => cmd_explain(rest.first(), args.json),
        Some(Command::Init) => cmd_init(rest.first(), args.opt("--name"), args.opt("--agent")),
        Some(Command::Examples) => cmd_examples(rest, &args),
        Some(Command::Coverage) => cmd_coverage(&paths, &args),
        Some(cmd) => {
            if args.json {
                println!("{}", json::error(cmd.name(), "not implemented yet"));
            } else {
                eprintln!("rootplc {}: not implemented yet", cmd.name());
            }
            ExitCode::from(1)
        }
        None => {
            eprintln!("unknown command '{first}'\n\n{USAGE}");
            ExitCode::from(2)
        }
    }
}
