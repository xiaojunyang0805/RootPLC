//! The `rootplc` binary. Argument parsing and output formatting only;
//! every command is implemented in `rootplc-driver`.

use rootplc_diag::{Severity, json_string};
use rootplc_driver::Command;
use std::path::PathBuf;
use std::process::ExitCode;

fn usage() -> String {
    let names: Vec<&str> = Command::ALL.iter().map(|c| c.name()).collect();
    format!(
        "usage: rootplc <{}|mcp> [--json]\n       rootplc check <file.st|dir>... [--json]",
        names.join("|")
    )
}

/// `rootplc check`. Exit codes: 0 no errors, 1 errors found, 2 usage or I/O error.
fn cmd_check(paths: &[PathBuf], json: bool) -> ExitCode {
    if paths.is_empty() {
        eprintln!(
            "rootplc check: give one or more .st files or directories\n{}",
            usage()
        );
        return ExitCode::from(2);
    }
    let report = match rootplc_driver::check(paths) {
        Ok(r) => r,
        Err(e) => {
            if json {
                println!(
                    "{{\"command\":\"check\",\"status\":\"io_error\",\"message\":{}}}",
                    json_string(&e)
                );
            } else {
                eprintln!("rootplc check: {e}");
            }
            return ExitCode::from(2);
        }
    };
    let (errors, warnings) = (
        report.count(Severity::Error),
        report.count(Severity::Warning),
    );
    if json {
        let diags: Vec<String> = report
            .files
            .iter()
            .flat_map(|f| {
                let name = f.path.display().to_string();
                f.diagnostics
                    .iter()
                    .map(move |d| d.render_json(&name, &f.source))
            })
            .collect();
        println!(
            "{{\"command\":\"check\",\"ok\":{},\"files\":{},\"errors\":{errors},\"warnings\":{warnings},\"diagnostics\":[{}]}}",
            report.ok(),
            report.files.len(),
            diags.join(",")
        );
    } else {
        for f in &report.files {
            let name = f.path.display().to_string();
            for d in &f.diagnostics {
                println!("{}", d.render_text(&name, &f.source));
            }
        }
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

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let json = args.iter().any(|a| a == "--json");
    let positional: Vec<&String> = args.iter().filter(|a| !a.starts_with('-')).collect();
    let Some(first) = positional.first() else {
        if args.iter().any(|a| a == "--version" || a == "-V") {
            println!("rootplc {}", env!("CARGO_PKG_VERSION"));
            return ExitCode::SUCCESS;
        }
        eprintln!("{}", usage());
        return ExitCode::from(2);
    };
    // `rootplc mcp` starts the MCP server on stdio (used by agent host configs).
    if first.as_str() == "mcp" {
        eprintln!("rootplc mcp: {}", rootplc_mcp::STATUS);
        return ExitCode::from(1);
    }
    match Command::from_name(first) {
        Some(Command::Check) => {
            let paths: Vec<PathBuf> = positional[1..].iter().map(PathBuf::from).collect();
            cmd_check(&paths, json)
        }
        Some(cmd) => {
            if json {
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
