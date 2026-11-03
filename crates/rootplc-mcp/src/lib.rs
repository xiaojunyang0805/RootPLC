//! MCP server exposing the toolchain to agents: `rootplc mcp` speaks the
//! Model Context Protocol (JSON-RPC 2.0, one message per line) on stdio.
//!
//! Roadmap phase: 1 (stdio in Phase 0 as D1a; HTTP later). See `ARCHITECTURE.md`.
//!
//! Tools: `rootplc_check`, `rootplc_test`, `rootplc_run`, `rootplc_explain`.
//! All are read-only: they never write files and never touch hardware.
//! Results are the same JSON reports as `rootplc <command> --json`.

pub mod json;

use std::io::{BufRead, Write};
use std::path::PathBuf;

use json::Json;

/// Implementation status, reported by `rootplc mcp --version`.
pub const STATUS: &str =
    "stdio MCP server: rootplc_check, rootplc_test, rootplc_run, rootplc_explain";

/// Protocol versions this server speaks, newest first.
pub const PROTOCOL_VERSIONS: &[&str] = &["2025-06-18", "2025-03-26", "2024-11-05"];

const INSTRUCTIONS: &str = "RootPLC checks, tests and runs IEC 61131-3 Structured Text (ST). \
Work in a loop: write ST, call rootplc_check until ok is true (fix every diagnostic; \
rootplc_explain gives the spec rule for a code), then write TEST blocks and call rootplc_test \
until every test passes. Do not report success while a check error or a failing test remains. \
Pass project files with `paths` (files or directories) or code with `source`. \
Deployment to real PLCs is not available to agents; a human approves it.";

const MAX_CYCLES: f64 = 1_000_000.0;

fn source_props() -> &'static str {
    r#""paths":{"type":"array","items":{"type":"string"},"description":"Project files or directories (.st, searched recursively). All files form one project."},"source":{"type":"string","description":"Structured Text to check without writing a file. Combined with paths if both are given."},"files":{"type":"array","description":"Several in-memory files.","items":{"type":"object","properties":{"name":{"type":"string"},"source":{"type":"string"}},"required":["name","source"]}}"#
}

fn tools() -> String {
    let src = source_props();
    let ro = r#""annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":false}"#;
    format!(
        r#"{{"tools":[
{{"name":"rootplc_check","title":"Check Structured Text","description":"Lex, parse and type-check IEC 61131-3 Structured Text. Returns diagnostics with stable codes (RPnnnn), 1-based positions and fix hints. ok is true when there are no errors.","inputSchema":{{"type":"object","properties":{{{src}}}}},{ro}}},
{{"name":"rootplc_test","title":"Run TEST blocks","description":"Compile the project and run every TEST ... END_TEST block in the deterministic VM. Assertions: ASSERT_TRUE, ASSERT_FALSE, ASSERT_EQ, ASSERT_NE. Tests may read every variable of an instance (white-box). Returns pass/fail per test with failure locations and run-time faults.","inputSchema":{{"type":"object","properties":{{{src},"filter":{{"type":"string","description":"Only tests whose name contains this text."}}}}}},{ro}}},
{{"name":"rootplc_run","title":"Run a program","description":"Compile and run one PROGRAM for a number of PLC cycles in the VM (virtual clock), then return the value of every variable. Use it to inspect behaviour; use rootplc_test for pass/fail evidence.","inputSchema":{{"type":"object","properties":{{{src},"program":{{"type":"string","description":"PROGRAM to run; optional when there is only one."}},"cycles":{{"type":"integer","minimum":1,"maximum":1000000,"default":1}},"cycle_ms":{{"type":"integer","minimum":0,"default":10,"description":"Virtual time per cycle in milliseconds (timers use it)."}}}}}},{ro}}},
{{"name":"rootplc_explain","title":"Explain a diagnostic","description":"Explain a diagnostic code such as RP0103: severity, summary and the text of the spec rule that defines it.","inputSchema":{{"type":"object","properties":{{"code":{{"type":"string","description":"Diagnostic code, e.g. RP0103 or 103."}}}},"required":["code"]}},{ro}}}
]}}"#
    )
}

fn rpc_result(id: &Json, result: &str) -> String {
    format!(
        "{{\"jsonrpc\":\"2.0\",\"id\":{},\"result\":{result}}}",
        id.write()
    )
}

fn rpc_error(id: &Json, code: i32, message: &str) -> String {
    format!(
        "{{\"jsonrpc\":\"2.0\",\"id\":{},\"error\":{{\"code\":{code},\"message\":{}}}}}",
        id.write(),
        rootplc_diag::json_string(message)
    )
}

/// Tool result: the report as text content.
fn tool_result(report: &str, is_error: bool) -> String {
    format!(
        "{{\"content\":[{{\"type\":\"text\",\"text\":{}}}],\"isError\":{is_error}}}",
        rootplc_diag::json_string(report)
    )
}

/// Collect sources from `paths`, `files` and `source`.
fn sources(args: &Json) -> Result<Vec<(PathBuf, String)>, String> {
    let mut out = Vec::new();
    if let Some(paths) = args.get("paths").and_then(Json::as_array) {
        let paths: Vec<PathBuf> = paths
            .iter()
            .filter_map(Json::as_str)
            .map(PathBuf::from)
            .collect();
        out.extend(rootplc_driver::read_sources(&paths)?);
    }
    if let Some(files) = args.get("files").and_then(Json::as_array) {
        for f in files {
            let (Some(name), Some(src)) = (
                f.get("name").and_then(Json::as_str),
                f.get("source").and_then(Json::as_str),
            ) else {
                return Err("each entry of files needs name and source".into());
            };
            out.push((PathBuf::from(name), src.to_string()));
        }
    }
    if let Some(src) = args.get("source").and_then(Json::as_str) {
        out.push((PathBuf::from("input.st"), src.to_string()));
    }
    if out.is_empty() {
        return Err("give paths, files or source".into());
    }
    Ok(out)
}

fn call_tool(name: &str, args: &Json) -> String {
    let fail = |cmd: &str, msg: &str| tool_result(&rootplc_driver::json::error(cmd, msg), true);
    match name {
        "rootplc_check" => match sources(args) {
            Ok(s) => tool_result(
                &rootplc_driver::json::check(&rootplc_driver::check_sources(s)),
                false,
            ),
            Err(e) => fail("check", &e),
        },
        "rootplc_test" => match sources(args) {
            Ok(s) => {
                let filter = args.get("filter").and_then(Json::as_str);
                let r = rootplc_driver::test_report(rootplc_driver::check_sources(s), filter);
                tool_result(&rootplc_driver::json::test(&r), false)
            }
            Err(e) => fail("test", &e),
        },
        "rootplc_run" => match sources(args) {
            Ok(s) => {
                let program = args.get("program").and_then(Json::as_str);
                let cycles = args
                    .get("cycles")
                    .and_then(Json::as_f64)
                    .unwrap_or(1.0)
                    .clamp(1.0, MAX_CYCLES) as u64;
                let cycle_ms = args
                    .get("cycle_ms")
                    .and_then(Json::as_f64)
                    .unwrap_or(10.0)
                    .max(0.0) as i128;
                match rootplc_driver::run_report(
                    rootplc_driver::check_sources(s),
                    program,
                    cycles,
                    cycle_ms * 1_000_000,
                ) {
                    Ok(r) => tool_result(&rootplc_driver::json::run(&r), false),
                    Err(e) => fail("run", &e),
                }
            }
            Err(e) => fail("run", &e),
        },
        "rootplc_explain" => {
            let code = args.get("code").and_then(Json::as_str).unwrap_or("");
            match rootplc_driver::explain::explain(code) {
                Some(e) => tool_result(&rootplc_driver::json::explain(&e), false),
                None => fail("explain", &format!("unknown diagnostic code '{code}'")),
            }
        }
        _ => fail(name, "unknown tool"),
    }
}

/// Handle one JSON-RPC message; `None` for notifications.
pub fn handle(line: &str) -> Option<String> {
    let msg = match json::parse(line) {
        Ok(m) => m,
        Err(e) => return Some(rpc_error(&Json::Null, -32700, &format!("parse error: {e}"))),
    };
    let id = msg.get("id").cloned();
    let Some(method) = msg.get("method").and_then(Json::as_str) else {
        // a response from the client, or an invalid message
        return id.map(|id| rpc_error(&id, -32600, "invalid request"));
    };
    let id = id?; // notifications get no response
    let params = msg.get("params").cloned().unwrap_or(Json::Obj(Vec::new()));
    Some(match method {
        "initialize" => {
            let asked = params
                .get("protocolVersion")
                .and_then(Json::as_str)
                .unwrap_or("");
            let version = PROTOCOL_VERSIONS
                .iter()
                .find(|v| **v == asked)
                .unwrap_or(&PROTOCOL_VERSIONS[0]);
            let result = format!(
                "{{\"protocolVersion\":\"{version}\",\"capabilities\":{{\"tools\":{{\"listChanged\":false}}}},\
                 \"serverInfo\":{{\"name\":\"rootplc\",\"title\":\"RootPLC\",\"version\":\"{}\"}},\"instructions\":{}}}",
                env!("CARGO_PKG_VERSION"),
                rootplc_diag::json_string(INSTRUCTIONS)
            );
            rpc_result(&id, &result)
        }
        "ping" => rpc_result(&id, "{}"),
        "tools/list" => rpc_result(&id, &tools().replace('\n', "")),
        "tools/call" => {
            let Some(name) = params.get("name").and_then(Json::as_str) else {
                return Some(rpc_error(&id, -32602, "tools/call needs a tool name"));
            };
            let args = params
                .get("arguments")
                .cloned()
                .unwrap_or(Json::Obj(Vec::new()));
            rpc_result(&id, &call_tool(name, &args))
        }
        _ => rpc_error(&id, -32601, &format!("method not found: {method}")),
    })
}

/// Serve on stdin/stdout until stdin closes. Logs go to stderr only.
pub fn serve_stdio() -> std::io::Result<()> {
    let stdin = std::io::stdin();
    let mut out = std::io::stdout().lock();
    for line in stdin.lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        if let Some(resp) = handle(&line) {
            writeln!(out, "{resp}")?;
            out.flush()?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn call(req: &str) -> Json {
        json::parse(&handle(req).expect("response")).expect("valid JSON")
    }

    fn tool(name: &str, args: &str) -> Json {
        let r = call(&format!(
            r#"{{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{{"name":"{name}","arguments":{args}}}}}"#
        ));
        let text = r
            .get("result")
            .and_then(|x| x.get("content"))
            .and_then(Json::as_array)
            .and_then(|c| c[0].get("text"))
            .and_then(Json::as_str)
            .expect("text")
            .to_string();
        json::parse(&text).expect("report is JSON")
    }

    #[test]
    fn handshake_and_listing() {
        let r = call(
            r#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}"#,
        );
        let res = r.get("result").expect("result");
        assert_eq!(
            res.get("protocolVersion").and_then(Json::as_str),
            Some("2025-03-26")
        );
        assert!(handle(r#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#).is_none());
        let r = call(r#"{"jsonrpc":"2.0","id":"a","method":"tools/list"}"#);
        let tools = r
            .get("result")
            .and_then(|x| x.get("tools"))
            .and_then(Json::as_array)
            .expect("tools");
        assert_eq!(tools.len(), 4);
        assert_eq!(r.get("id").and_then(Json::as_str), Some("a"));
        let r = call(r#"{"jsonrpc":"2.0","id":2,"method":"nope"}"#);
        assert!(r.get("error").is_some());
        let r = call("{not json");
        assert!(r.get("error").is_some());
    }

    #[test]
    fn tools_work_on_inline_source() {
        let bad = r#"{"source":"PROGRAM p VAR s : SINT; i : INT; END_VAR s := i; END_PROGRAM"}"#;
        let rep = tool("rootplc_check", bad);
        assert_eq!(rep.get("ok"), Some(&Json::Bool(false)));
        let d = &rep
            .get("diagnostics")
            .and_then(Json::as_array)
            .expect("diags")[0];
        assert_eq!(d.get("code").and_then(Json::as_str), Some("RP0103"));

        let src = r#"{"source":"FUNCTION_BLOCK C VAR_INPUT x : BOOL; END_VAR VAR n : INT; END_VAR IF x THEN n := n + 1; END_IF END_FUNCTION_BLOCK\nTEST t VAR c : C; END_VAR c(x := TRUE); ASSERT_EQ(1, c.n); END_TEST"}"#;
        let rep = tool("rootplc_test", src);
        assert_eq!(rep.get("ok"), Some(&Json::Bool(true)), "{}", rep.write());

        let src =
            r#"{"source":"PROGRAM p VAR n : INT; END_VAR n := n + 2; END_PROGRAM","cycles":3}"#;
        let rep = tool("rootplc_run", src);
        assert_eq!(
            rep.get("variables")
                .and_then(|v| v.get("n"))
                .and_then(Json::as_str),
            Some("6")
        );

        let rep = tool("rootplc_explain", r#"{"code":"103"}"#);
        assert_eq!(
            rep.get("rule").and_then(Json::as_str),
            Some("types.conversion.implicit")
        );
        let rep = tool("rootplc_check", "{}");
        assert_eq!(rep.get("ok"), Some(&Json::Bool(false)));
    }
}
