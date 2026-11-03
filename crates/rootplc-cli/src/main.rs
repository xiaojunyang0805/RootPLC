//! The `rootplc` binary. Argument parsing and output formatting only;
//! every command is implemented in `rootplc-driver`.

use rootplc_driver::Command;
use std::process::ExitCode;

fn usage() -> String {
    let names: Vec<&str> = Command::ALL.iter().map(|c| c.name()).collect();
    format!("usage: rootplc <{}|mcp> [--json]", names.join("|"))
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let json = args.iter().any(|a| a == "--json");
    let Some(first) = args.iter().find(|a| !a.starts_with('-')) else {
        if args.iter().any(|a| a == "--version" || a == "-V") {
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
    match Command::from_name(first) {
        Some(cmd) => {
            if json {
                println!(
                    "{{\"command\":\"{}\",\"status\":\"not_implemented\"}}",
                    cmd.name()
                );
            } else {
                eprintln!("rootplc {}: not implemented yet (Phase 0)", cmd.name());
            }
            ExitCode::from(1)
        }
        None => {
            eprintln!("unknown command '{first}'\n{}", usage());
            ExitCode::from(2)
        }
    }
}
