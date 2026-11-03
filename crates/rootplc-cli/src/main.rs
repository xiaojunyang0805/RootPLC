//! The `rootplc` binary. Argument parsing and output formatting only;
//! every command is implemented in `rootplc-driver`.

use rootplc_diag::{Severity, json_string, line_col};
use rootplc_driver::{CheckReport, Command};
use std::path::PathBuf;
use std::process::ExitCode;

fn usage() -> String {
    let names: Vec<&str> = Command::ALL.iter().map(|c| c.name()).collect();
    format!(
        "usage: rootplc <{}|mcp> [--json]\n       \
         rootplc check <file.st|dir>... [--json]\n       \
         rootplc test  <file.st|dir>... [--filter TEXT] [--json]\n       \
         rootplc run   <file.st|dir>... [--program NAME] [--cycles N] [--cycle-ms MS] [--json]",
        names.join("|")
    )
}

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
                "--program" | "--cycles" | "--cycle-ms" | "--filter" => {
                    let v = it.next().unwrap_or_default();
                    a.options.push((x, v));
                }
                _ => a.positional.push(x),
            }
        }
        a
    }

    fn opt(&self, name: &str) -> Option<&str> {
        self.options
            .iter()
            .rev()
            .find(|(k, _)| k == name)
            .map(|(_, v)| v.as_str())
    }
}

fn io_error(cmd: &str, e: &str, json: bool) -> ExitCode {
    if json {
        println!(
            "{{\"command\":\"{cmd}\",\"status\":\"io_error\",\"message\":{}}}",
            json_string(e)
        );
    } else {
        eprintln!("rootplc {cmd}: {e}");
    }
    ExitCode::from(2)
}

/// Diagnostics as JSON array elements, or printed as text.
fn diagnostics(report: &CheckReport, json: bool) -> Vec<String> {
    let mut out = Vec::new();
    for f in &report.files {
        let name = f.path.display().to_string();
        for d in &f.diagnostics {
            if json {
                out.push(d.render_json(&name, &f.source));
            } else {
                println!("{}", d.render_text(&name, &f.source));
            }
        }
    }
    out
}

/// File name and 1-based position of a VM location.
fn location(report: &CheckReport, file: usize, offset: u32) -> (String, usize, usize) {
    match report.ir_files.get(file).and_then(|&i| report.files.get(i)) {
        Some(f) => {
            let (l, c) = line_col(&f.source, offset);
            (f.path.display().to_string(), l, c)
        }
        None => (String::from("?"), 0, 0),
    }
}

fn located_json(report: &CheckReport, file: usize, offset: u32, extra: &str) -> String {
    let (name, l, c) = location(report, file, offset);
    format!(
        "{{\"file\":{},\"line\":{l},\"column\":{c},{extra}}}",
        json_string(&name)
    )
}

fn fault_json(report: &CheckReport, f: Option<&rootplc_vm::Fault>) -> String {
    f.map_or("null".to_string(), |f| {
        let extra = format!(
            "\"kind\":\"{}\",\"message\":{}",
            f.kind.name(),
            json_string(&f.message)
        );
        located_json(report, f.file, f.span.start, &extra)
    })
}

/// `rootplc check`. Exit codes: 0 no errors, 1 errors found, 2 usage or I/O error.
fn cmd_check(paths: &[PathBuf], json: bool) -> ExitCode {
    let report = match rootplc_driver::check(paths) {
        Ok(r) => r,
        Err(e) => return io_error("check", &e, json),
    };
    let (errors, warnings) = (
        report.count(Severity::Error),
        report.count(Severity::Warning),
    );
    let diags = diagnostics(&report, json);
    if json {
        println!(
            "{{\"command\":\"check\",\"ok\":{},\"files\":{},\"errors\":{errors},\"warnings\":{warnings},\"diagnostics\":[{}]}}",
            report.ok(),
            report.files.len(),
            diags.join(",")
        );
    } else {
        eprintln!(
            "checked {} file(s): {errors} error(s), {warnings} warning(s)",
            report.files.len()
        );
    }
    if report.ok() {
        ExitCode::SUCCESS
    } else {
        ExitCode::from(1)
    }
}

/// `rootplc test`. Exit codes: 0 all passed, 1 compile errors or failures, 2 usage or I/O.
fn cmd_test(paths: &[PathBuf], filter: Option<&str>, json: bool) -> ExitCode {
    let r = match rootplc_driver::test(paths, filter) {
        Ok(r) => r,
        Err(e) => return io_error("test", &e, json),
    };
    let diags = diagnostics(&r.check, json);
    let passed = r.outcomes.iter().filter(|o| o.passed()).count();
    let failed = r.outcomes.len() - passed;
    if json {
        let tests: Vec<String> = r
            .outcomes
            .iter()
            .map(|o| {
                let failures: Vec<String> = o
                    .failures
                    .iter()
                    .map(|f| {
                        let extra = format!("\"message\":{}", json_string(&f.message));
                        located_json(&r.check, f.file, f.span.start, &extra)
                    })
                    .collect();
                format!(
                    "{{\"name\":{},\"passed\":{},\"failures\":[{}],\"fault\":{}}}",
                    json_string(&o.name),
                    o.passed(),
                    failures.join(","),
                    fault_json(&r.check, o.fault.as_ref())
                )
            })
            .collect();
        println!(
            "{{\"command\":\"test\",\"ok\":{},\"compiled\":{},\"passed\":{passed},\"failed\":{failed},\"diagnostics\":[{}],\"tests\":[{}]}}",
            r.ok(),
            r.check.ok(),
            diags.join(","),
            tests.join(",")
        );
    } else {
        for o in &r.outcomes {
            println!("{} {}", if o.passed() { "PASS" } else { "FAIL" }, o.name);
            for f in &o.failures {
                let (n, l, c) = location(&r.check, f.file, f.span.start);
                println!("  {n}:{l}:{c}: {}", f.message);
            }
            if let Some(f) = &o.fault {
                let (n, l, c) = location(&r.check, f.file, f.span.start);
                println!("  {n}:{l}:{c}: fault {}: {}", f.kind.name(), f.message);
            }
        }
        if r.check.ok() {
            eprintln!("{passed} passed, {failed} failed");
        } else {
            eprintln!("compilation failed; no tests were run");
        }
    }
    if r.ok() {
        ExitCode::SUCCESS
    } else {
        ExitCode::from(1)
    }
}

/// `rootplc run`. Exit codes: 0 ran, 1 compile errors or fault, 2 usage or I/O.
fn cmd_run(paths: &[PathBuf], args: &Args) -> ExitCode {
    let json = args.json;
    let cycles = args
        .opt("--cycles")
        .and_then(|v| v.parse().ok())
        .unwrap_or(1);
    let cycle_ms: i128 = args
        .opt("--cycle-ms")
        .and_then(|v| v.parse().ok())
        .unwrap_or(10);
    let r = match rootplc_driver::run(paths, args.opt("--program"), cycles, cycle_ms * 1_000_000) {
        Ok(r) => r,
        Err(e) => return io_error("run", &e, json),
    };
    let diags = diagnostics(&r.check, json);
    let ok = r.check.ok() && r.fault.is_none();
    if json {
        let vars: Vec<String> = r
            .variables
            .iter()
            .map(|(n, v)| format!("{}:{}", json_string(n), json_string(v)))
            .collect();
        println!(
            "{{\"command\":\"run\",\"ok\":{ok},\"program\":{},\"cycles\":{},\"fault\":{},\"diagnostics\":[{}],\"variables\":{{{}}}}}",
            json_string(&r.program),
            r.cycles,
            fault_json(&r.check, r.fault.as_ref()),
            diags.join(","),
            vars.join(",")
        );
    } else if r.check.ok() {
        println!("{} after {} cycle(s):", r.program, r.cycles);
        for (n, v) in &r.variables {
            println!("  {n} = {v}");
        }
        if let Some(f) = &r.fault {
            let (n, l, c) = location(&r.check, f.file, f.span.start);
            println!("{n}:{l}:{c}: fault {}: {}", f.kind.name(), f.message);
        }
    }
    if ok {
        ExitCode::SUCCESS
    } else {
        ExitCode::from(1)
    }
}

fn main() -> ExitCode {
    let args = Args::parse();
    let Some(first) = args.positional.first() else {
        if std::env::args().any(|a| a == "--version" || a == "-V") {
            println!("rootplc {}", env!("CARGO_PKG_VERSION"));
            return ExitCode::SUCCESS;
        }
        eprintln!("{}", usage());
        return ExitCode::from(2);
    };
    // `rootplc mcp` starts the MCP server on stdio (used by agent host configs).
    if first == "mcp" {
        eprintln!("rootplc mcp: {}", rootplc_mcp::STATUS);
        return ExitCode::from(1);
    }
    let paths: Vec<PathBuf> = args.positional[1..].iter().map(PathBuf::from).collect();
    let cmd = Command::from_name(first);
    if matches!(cmd, Some(Command::Check | Command::Test | Command::Run)) && paths.is_empty() {
        eprintln!(
            "rootplc {first}: give one or more .st files or directories\n{}",
            usage()
        );
        return ExitCode::from(2);
    }
    match cmd {
        Some(Command::Check) => cmd_check(&paths, args.json),
        Some(Command::Test) => cmd_test(&paths, args.opt("--filter"), args.json),
        Some(Command::Run) => cmd_run(&paths, &args),
        Some(cmd) => {
            if args.json {
                println!(
                    "{{\"command\":\"{}\",\"status\":\"not_implemented\"}}",
                    cmd.name()
                );
            } else {
                eprintln!("rootplc {}: not implemented yet", cmd.name());
            }
            ExitCode::from(1)
        }
        None => {
            eprintln!("unknown command '{first}'\n{}", usage());
            ExitCode::from(2)
        }
    }
}
