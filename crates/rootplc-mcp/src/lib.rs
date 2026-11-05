//! MCP server exposing the toolchain to agents: `rootplc mcp` speaks the
//! Model Context Protocol (JSON-RPC 2.0, one message per line) on stdio.
//!
//! Roadmap phase: 1 (stdio in Phase 0 as D1a; HTTP later). See `ARCHITECTURE.md`.
//!
//! Tools: `rootplc_check`, `rootplc_test`, `rootplc_run`, `rootplc_diff`,
//! `rootplc_evidence`, `rootplc_explain`, `rootplc_examples`, `rootplc_coverage`. All are read-only: they never
//! write files and never touch hardware. Results are the same JSON reports
//! as `rootplc <command> --json`.
//!
//! Resources: the agent guide (AGENTS.md), the language spec chapters, the
//! diagnostic registry and every verified example. Prompts: the three
//! standard workflows (write and verify, fix diagnostics, port legacy code).

pub mod json;

use std::io::{BufRead, Write};
use std::path::PathBuf;

use json::Json;

/// Implementation status, reported by `rootplc mcp --version`.
pub const STATUS: &str = "stdio MCP server: rootplc_check, rootplc_test, rootplc_run, rootplc_diff, rootplc_evidence, \
     rootplc_explain, rootplc_examples, rootplc_coverage; resources; prompts";

/// Protocol versions this server speaks, newest first.
pub const PROTOCOL_VERSIONS: &[&str] = &["2025-06-18", "2025-03-26", "2024-11-05"];

const INSTRUCTIONS: &str = "RootPLC checks, tests and runs IEC 61131-3 Structured Text (ST). \
Work in a loop: write ST, call rootplc_check until ok is true (fix every diagnostic; \
rootplc_explain gives the spec rule for a code), then write TEST blocks and call rootplc_test \
until every test passes. Do not report success while a check error or a failing test remains. \
Before writing a common pattern (timers, edges, state machines, interlocks), call \
rootplc_examples for verified code. For an existing code base, call rootplc_coverage first: \
it says which files RootPLC can take as they are and which use vendor constructs. To check that a function block behaves like another (after a refactoring, or a real block against a RootBlocks catalog block), call rootplc_diff. \
Pass project files with `paths` (files or directories) or code with `source`. \
Deployment to real PLCs is not available to agents; a human approves it.";

const MAX_CYCLES: f64 = 1_000_000.0;

fn source_props() -> &'static str {
    r#""libraries":{"type":"array","items":{"type":"string"},"description":"Compatibility libraries to activate, e.g. [\"Tc2_System\", \"TwinCAT_BuiltIns\"] for TwinCAT code."},"paths":{"type":"array","items":{"type":"string"},"description":"Project files or directories (.st, searched recursively). All files form one project."},"source":{"type":"string","description":"Structured Text to check without writing a file. Combined with paths if both are given."},"files":{"type":"array","description":"Several in-memory files.","items":{"type":"object","properties":{"name":{"type":"string"},"source":{"type":"string"}},"required":["name","source"]}}"#
}

fn tools() -> String {
    let src = source_props();
    let ro = r#""annotations":{"readOnlyHint":true,"destructiveHint":false,"idempotentHint":true,"openWorldHint":false}"#;
    format!(
        r#"{{"tools":[
{{"name":"rootplc_check","title":"Check Structured Text","description":"Lex, parse and type-check IEC 61131-3 Structured Text. Returns diagnostics with stable codes (RPnnnn), 1-based positions and fix hints. ok is true when there are no errors.","inputSchema":{{"type":"object","properties":{{{src}}}}},{ro}}},
{{"name":"rootplc_test","title":"Run TEST blocks","description":"Compile the project and run every TEST ... END_TEST block in the deterministic VM. Assertions: ASSERT_TRUE, ASSERT_FALSE, ASSERT_EQ, ASSERT_NE. Tests may read every variable of an instance (white-box). Returns pass/fail per test with failure locations and run-time faults. With mutate: true, measures how good the tests are instead: every small change to the code (a flipped comparison, AND/OR, TRUE/FALSE, n to n+1, a doubled duration) must make a test fail; returns the mutation score and each surviving change, so you can add a test for it.","inputSchema":{{"type":"object","properties":{{{src},"filter":{{"type":"string","description":"Only tests whose name contains this text."}},"mutate":{{"type":"boolean","default":false,"description":"Run mutation testing (needs all tests passing first)."}},"mutate_limit":{{"type":"integer","minimum":1,"maximum":5000,"default":500}},"mutate_only":{{"type":"string","description":"Mutate only files whose path contains this text; tests and other files still run."}},"slice":{{"type":"boolean","default":false,"description":"Compile only the files the TEST blocks need, so errors in unrelated files do not stop the tests."}}}}}},{ro}}},
{{"name":"rootplc_run","title":"Run a program","description":"Compile and run one PROGRAM for a number of PLC cycles in the VM (virtual clock), then return the value of every variable. Use it to inspect behaviour; use rootplc_test for pass/fail evidence.","inputSchema":{{"type":"object","properties":{{{src},"program":{{"type":"string","description":"PROGRAM to run; optional when there is only one."}},"cycles":{{"type":"integer","minimum":1,"maximum":1000000,"default":1}},"cycle_ms":{{"type":"integer","minimum":0,"default":10,"description":"Virtual time per cycle in milliseconds (timers use it)."}}}}}},{ro}}},
{{"name":"rootplc_diff","title":"Compare a block with a reference","description":"Run two function blocks side by side in the VM, give them the same seeded pseudo-random inputs every cycle and compare their outputs. Inputs and outputs are matched by name; wrap a block with other names in a small adapter FB that has the reference's names. BOOL inputs toggle, numeric inputs jump within a range; other inputs keep their initial value unless set. Returns the verdict (agree / differ / fault), per output the cycles that differed, and the first difference with the inputs of that cycle and the four before, so you can turn it into a TEST. Agreement covers the sampled cycles only.","inputSchema":{{"type":"object","properties":{{{src},"reference":{{"type":"string","description":"The reference FUNCTION_BLOCK, e.g. RB_Motor (with libraries [\"RootBlocks\"])."}},"unit":{{"type":"string","description":"The FUNCTION_BLOCK to compare."}},"cycles":{{"type":"integer","minimum":1,"maximum":1000000,"default":1000}},"cycle_ms":{{"type":"integer","minimum":0,"default":10}},"seed":{{"type":"integer","minimum":0,"default":1}},"set":{{"type":"array","items":{{"type":"string"}},"description":"Inputs held at a value, e.g. [\"Mode=RB_MODE#Auto\", \"Delay=T#2s\"]."}},"ranges":{{"type":"array","items":{{"type":"string"}},"description":"Ranges of numeric inputs, e.g. [\"SP=0..80\"]; default 0..100."}},"toggle":{{"type":"number","minimum":0,"maximum":1,"default":0.1,"description":"Probability that an input changes in a cycle."}},"tolerance":{{"type":"number","minimum":0,"default":0.0001,"description":"Allowed difference of REAL outputs."}}}},"required":["reference","unit"]}},{ro}}},
{{"name":"rootplc_evidence","title":"Evidence pack for sign-off","description":"Build the evidence pack an engineer reviews before approving a change: input file hashes, check result (IEC clean or not), every test result, the mutation score with surviving changes, and a verdict (verified / not verified with reasons). Deterministic; never signed locally. Call it last, after rootplc_test passes.","inputSchema":{{"type":"object","properties":{{{src},"min_score":{{"type":"number","minimum":0,"maximum":100,"description":"Required mutation score in percent."}},"mutate":{{"type":"boolean","default":true}},"markdown":{{"type":"boolean","default":false,"description":"Return a readable summary instead of JSON."}}}}}},{ro}}},
{{"name":"rootplc_explain","title":"Explain a diagnostic","description":"Explain a diagnostic code such as RP0103: severity, summary and the text of the spec rule that defines it.","inputSchema":{{"type":"object","properties":{{"code":{{"type":"string","description":"Diagnostic code, e.g. RP0103 or 103."}}}},"required":["code"]}},{ro}}},
{{"name":"rootplc_examples","title":"Find verified ST patterns","description":"Search a library of Structured Text patterns (edge detection, timers, counters, state machines, interlocks, arrays, structs, test blocks). Every example compiles and passes its TEST blocks in this toolchain version. Adapt them; do not copy names blindly.","inputSchema":{{"type":"object","properties":{{"query":{{"type":"string","description":"Keywords, e.g. 'timer' or 'state machine'. Empty lists every example."}},"id":{{"type":"string","description":"Return this one example, e.g. 'edge-detect'."}}}}}},{ro}}},
{{"name":"rootplc_coverage","title":"Coverage of a code base","description":"Check every file and classify it: portable (compiles; can be tested now), dialect (uses vendor or IEC ed.3 OOP constructs RootPLC does not support yet; lists them with lines), dependent (fails only because a file it uses fails) or blocked (other errors). Use it before porting or testing existing PLC code.","inputSchema":{{"type":"object","properties":{{{src}}}}},{ro}}}
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

/// The `libraries` argument ([stdlib.compat]).
fn libraries(args: &Json) -> Vec<String> {
    args.get("libraries")
        .and_then(Json::as_array)
        .map(|v| {
            v.iter()
                .filter_map(Json::as_str)
                .map(str::to_string)
                .collect()
        })
        .unwrap_or_default()
}

/// Check sources with the `libraries` argument ([stdlib.compat]).
fn checked(s: Vec<(PathBuf, String)>, args: &Json) -> Result<rootplc_driver::CheckReport, String> {
    rootplc_driver::check_sources_with(s, &libraries(args))
}

/// The `slice` argument ([tests.slice]).
fn sliced(s: Vec<(PathBuf, String)>, args: &Json) -> Vec<(PathBuf, String)> {
    if args.get("slice").and_then(Json::as_bool) == Some(true) {
        rootplc_driver::slice::slice_tests(s).0
    } else {
        s
    }
}

fn call_tool(name: &str, args: &Json) -> String {
    let fail = |cmd: &str, msg: &str| tool_result(&rootplc_driver::json::error(cmd, msg), true);
    match name {
        "rootplc_check" => match sources(args).and_then(|s| checked(s, args)) {
            Ok(c) => tool_result(&rootplc_driver::json::check(&c), false),
            Err(e) => fail("check", &e),
        },
        "rootplc_test" if args.get("mutate").and_then(Json::as_bool) == Some(true) => {
            let filter = args.get("filter").and_then(Json::as_str);
            let limit = args
                .get("mutate_limit")
                .and_then(Json::as_f64)
                .map_or(rootplc_driver::mutate::DEFAULT_LIMIT, |n| {
                    n.clamp(1.0, 5000.0) as usize
                });
            match sources(args).map(|s| sliced(s, args)).and_then(|s| {
                rootplc_driver::mutate::mutation_report_only(
                    s,
                    &libraries(args),
                    filter,
                    limit,
                    args.get("mutate_only").and_then(Json::as_str),
                )
            }) {
                Ok(r) => tool_result(&rootplc_driver::json::mutation(&r, None), false),
                Err(e) => fail("test", &e),
            }
        }
        "rootplc_test" => match sources(args)
            .map(|s| sliced(s, args))
            .and_then(|s| checked(s, args))
        {
            Ok(c) => {
                let filter = args.get("filter").and_then(Json::as_str);
                let r = rootplc_driver::test_report(c, filter);
                tool_result(&rootplc_driver::json::test(&r), false)
            }
            Err(e) => fail("test", &e),
        },
        "rootplc_evidence" => {
            let opts = rootplc_driver::evidence::Options {
                libraries: libraries(args),
                mutate: args.get("mutate").and_then(Json::as_bool) != Some(false),
                min_score: args.get("min_score").and_then(Json::as_f64),
                ..rootplc_driver::evidence::Options::default()
            };
            match sources(args).and_then(|s| rootplc_driver::evidence::evidence(s, &opts)) {
                Ok(e) if args.get("markdown").and_then(Json::as_bool) == Some(true) => {
                    tool_result(&rootplc_driver::evidence::to_markdown(&e), false)
                }
                Ok(e) => tool_result(&rootplc_driver::evidence::to_json(&e), false),
                Err(e) => fail("evidence", &e),
            }
        }
        "rootplc_run" => match sources(args).and_then(|s| checked(s, args)) {
            Ok(c) => {
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
                match rootplc_driver::run_report(c, program, cycles, cycle_ms * 1_000_000) {
                    Ok(r) => tool_result(&rootplc_driver::json::run(&r), false),
                    Err(e) => fail("run", &e),
                }
            }
            Err(e) => fail("run", &e),
        },
        "rootplc_diff" => {
            let strings = |key: &str| -> Vec<String> {
                args.get(key)
                    .and_then(Json::as_array)
                    .map(|v| {
                        v.iter()
                            .filter_map(Json::as_str)
                            .map(str::to_string)
                            .collect()
                    })
                    .unwrap_or_default()
            };
            let mut opt = rootplc_driver::diff::DiffOptions {
                reference: args
                    .get("reference")
                    .and_then(Json::as_str)
                    .unwrap_or_default()
                    .to_string(),
                unit: args
                    .get("unit")
                    .and_then(Json::as_str)
                    .unwrap_or_default()
                    .to_string(),
                ..rootplc_driver::diff::DiffOptions::default()
            };
            if let Some(n) = args.get("cycles").and_then(Json::as_f64) {
                opt.cycles = n.clamp(1.0, MAX_CYCLES) as u64;
            }
            if let Some(n) = args.get("cycle_ms").and_then(Json::as_f64) {
                opt.cycle_ms = n.max(0.0) as u64;
            }
            if let Some(n) = args.get("seed").and_then(Json::as_f64) {
                opt.seed = n.max(0.0) as u64;
            }
            if let Some(n) = args.get("toggle").and_then(Json::as_f64) {
                opt.toggle = n.clamp(0.0, 1.0);
            }
            if let Some(n) = args.get("tolerance").and_then(Json::as_f64) {
                opt.tolerance = n.max(0.0);
            }
            for item in strings("set") {
                match item.split_once('=') {
                    Some((n, v)) => opt.set.push((n.trim().into(), v.trim().into())),
                    None => return fail("diff", &format!("set {item}: write NAME=VALUE")),
                }
            }
            for item in strings("ranges") {
                let parsed = item.split_once('=').and_then(|(n, rg)| {
                    let (lo, hi) = rg.split_once("..")?;
                    Some((
                        n.trim().to_string(),
                        lo.trim().parse().ok()?,
                        hi.trim().parse().ok()?,
                    ))
                });
                match parsed {
                    Some(rg) => opt.ranges.push(rg),
                    None => return fail("diff", &format!("ranges {item}: write NAME=LO..HI")),
                }
            }
            match sources(args)
                .and_then(|s| rootplc_driver::diff::diff_sources(s, &libraries(args), &opt))
            {
                Ok(rootplc_driver::diff::DiffRun::NotCompiling(c)) => {
                    tool_result(&rootplc_driver::json::check(&c), true)
                }
                Ok(rootplc_driver::diff::DiffRun::Report(rep)) => {
                    tool_result(&rootplc_driver::diff::to_json(&rep), false)
                }
                Err(e) => fail("diff", &e),
            }
        }
        "rootplc_examples" => {
            let found = match args.get("id").and_then(Json::as_str) {
                Some(id) => match rootplc_driver::examples::get(id) {
                    Some(e) => vec![e],
                    None => return fail("examples", &format!("no example '{id}'")),
                },
                None => rootplc_driver::examples::search(
                    args.get("query").and_then(Json::as_str).unwrap_or(""),
                ),
            };
            let query = args
                .get("query")
                .or_else(|| args.get("id"))
                .and_then(Json::as_str)
                .unwrap_or("");
            tool_result(&rootplc_driver::json::examples(query, &found, true), false)
        }
        "rootplc_coverage" => {
            let libs: Vec<String> = args
                .get("libraries")
                .and_then(Json::as_array)
                .map(|v| {
                    v.iter()
                        .filter_map(Json::as_str)
                        .map(str::to_string)
                        .collect()
                })
                .unwrap_or_default();
            match sources(args)
                .and_then(|s| rootplc_driver::coverage::coverage_sources_with(s, &libs))
            {
                Ok(r) => tool_result(&rootplc_driver::json::coverage(&r), false),
                Err(e) => fail("coverage", &e),
            }
        }
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

/// Every resource: (uri, name, title, mime type, text).
fn resources() -> Vec<(String, String, String, &'static str, &'static str)> {
    let mut out = vec![
        (
            "rootplc://guide/AGENTS.md".to_string(),
            "AGENTS.md".to_string(),
            "How an agent works with RootPLC".to_string(),
            "text/markdown",
            rootplc_driver::init::AGENTS_MD,
        ),
        (
            "rootplc://spec/diagnostics.toml".to_string(),
            "diagnostics.toml".to_string(),
            "Every diagnostic code, its severity and spec rule".to_string(),
            "application/toml",
            rootplc_driver::explain::REGISTRY,
        ),
    ];
    for &(path, text) in rootplc_driver::explain::SPEC {
        let name = path.trim_start_matches("spec/");
        out.push((
            format!("rootplc://spec/{name}"),
            name.to_string(),
            format!("Language spec: {name}"),
            "text/markdown",
            text,
        ));
    }
    for e in rootplc_driver::examples::all() {
        out.push((
            format!("rootplc://examples/{}", e.id),
            format!("{}.st", e.id),
            format!("Verified example: {}", e.title),
            "text/plain",
            e.source,
        ));
    }
    out
}

fn resources_list() -> String {
    let items: Vec<String> = resources()
        .iter()
        .map(|(uri, name, title, mime, text)| {
            format!(
                "{{\"uri\":{},\"name\":{},\"title\":{},\"mimeType\":\"{mime}\",\"size\":{}}}",
                rootplc_diag::json_string(uri),
                rootplc_diag::json_string(name),
                rootplc_diag::json_string(title),
                text.len()
            )
        })
        .collect();
    format!("{{\"resources\":[{}]}}", items.join(","))
}

fn resource_read(uri: &str) -> Option<String> {
    let (uri, _, _, mime, text) = resources().into_iter().find(|r| r.0 == uri)?;
    Some(format!(
        "{{\"contents\":[{{\"uri\":{},\"mimeType\":\"{mime}\",\"text\":{}}}]}}",
        rootplc_diag::json_string(&uri),
        rootplc_diag::json_string(text)
    ))
}

/// Prompts: (name, title, description, argument, argument description).
const PROMPTS: &[(&str, &str, &str, &str, &str)] = &[
    (
        "write_and_verify",
        "Write and verify Structured Text",
        "Write IEC 61131-3 Structured Text for a task and prove it with passing TEST blocks.",
        "task",
        "What the program must do.",
    ),
    (
        "fix_diagnostics",
        "Fix every diagnostic",
        "Check a project, explain each diagnostic code and fix the code until the check is clean.",
        "path",
        "Project file or directory.",
    ),
    (
        "port_legacy",
        "Port existing PLC code",
        "Assess an existing code base with coverage, then bring files to portable IEC 61131-3 with tests as evidence.",
        "path",
        "Directory of the existing code.",
    ),
];

fn prompt_text(name: &str, arg: &str) -> Option<String> {
    Some(match name {
        "write_and_verify" => format!(
            "Task: {arg}\n\n\
             1. Call rootplc_examples with the main keywords of the task and reuse the verified patterns that fit.\n\
             2. Write the program in IEC 61131-3 Structured Text. Name inputs and outputs clearly.\n\
             3. Call rootplc_check until ok is true. For any code you do not understand, call rootplc_explain.\n\
             4. Write TEST blocks that state the required behaviour, including edge cases and timing (use ADVANCE for virtual time).\n\
             5. Call rootplc_test until every test passes. Do not weaken a test to make it pass.\n\
             6. Call rootplc_test with mutate: true. For each surviving change, add a test that fails on it, until the score is high.
\n             7. Report the final code, the test results and the mutation score. Never claim success while an error or a failing test remains."
        ),
        "fix_diagnostics" => format!(
            "Project: {arg}\n\n\
             1. Call rootplc_check with paths [\"{arg}\"].\n\
             2. For each distinct diagnostic code, call rootplc_explain to read the rule.\n\
             3. Fix the cause, not the symptom: use explicit conversions (e.g. INT_TO_SINT) instead of hiding a narrowing.\n\
             4. Repeat until ok is true, then call rootplc_test so behaviour is confirmed, not only syntax."
        ),
        "port_legacy" => format!(
            "Code base: {arg}\n\n\
             1. Call rootplc_coverage with paths [\"{arg}\"]. Summarise: portable, dialect, dependent and blocked counts.\n\
             2. Portable files: write TEST blocks that pin down their current behaviour and run rootplc_test.\n\
             3. Dialect files: for each listed construct, propose a strict IEC 61131-3 rewrite (for example explicit conversions for implicit narrowing; plain function blocks instead of METHODs where possible). Change one file at a time and keep the behaviour pinned by tests.\n\
             4. Dependent files usually become portable when the files they need do; fix those first.\n\
             5. Blocked files: call rootplc_check and rootplc_explain to see whether the code or RootPLC is at fault; report RootPLC gaps instead of working around them silently.\n\
             6. Do not deploy anything. Deployment to a PLC always needs a human."
        ),
        _ => return None,
    })
}

fn prompts_list() -> String {
    let items: Vec<String> = PROMPTS
        .iter()
        .map(|(name, title, desc, arg, arg_desc)| {
            format!(
                "{{\"name\":\"{name}\",\"title\":{},\"description\":{},\"arguments\":[{{\"name\":\"{arg}\",\"description\":{},\"required\":true}}]}}",
                rootplc_diag::json_string(title),
                rootplc_diag::json_string(desc),
                rootplc_diag::json_string(arg_desc)
            )
        })
        .collect();
    format!("{{\"prompts\":[{}]}}", items.join(","))
}

fn prompt_get(name: &str, args: &Json) -> Option<String> {
    let (_, _, desc, arg, _) = PROMPTS.iter().find(|p| p.0 == name)?;
    let value = args.get(arg).and_then(Json::as_str).unwrap_or("");
    let text = prompt_text(name, value)?;
    Some(format!(
        "{{\"description\":{},\"messages\":[{{\"role\":\"user\",\"content\":{{\"type\":\"text\",\"text\":{}}}}}]}}",
        rootplc_diag::json_string(desc),
        rootplc_diag::json_string(&text)
    ))
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
                "{{\"protocolVersion\":\"{version}\",\"capabilities\":{{\"tools\":{{\"listChanged\":false}},\"resources\":{{\"listChanged\":false}},\"prompts\":{{\"listChanged\":false}}}},\
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
        "resources/list" => rpc_result(&id, &resources_list()),
        "resources/templates/list" => rpc_result(&id, "{\"resourceTemplates\":[]}"),
        "resources/read" => {
            let uri = params.get("uri").and_then(Json::as_str).unwrap_or("");
            match resource_read(uri) {
                Some(r) => rpc_result(&id, &r),
                None => rpc_error(&id, -32002, &format!("resource not found: {uri}")),
            }
        }
        "prompts/list" => rpc_result(&id, &prompts_list()),
        "prompts/get" => {
            let name = params.get("name").and_then(Json::as_str).unwrap_or("");
            let args = params
                .get("arguments")
                .cloned()
                .unwrap_or(Json::Obj(Vec::new()));
            match prompt_get(name, &args) {
                Some(r) => rpc_result(&id, &r),
                None => rpc_error(&id, -32602, &format!("unknown prompt: {name}")),
            }
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
        assert_eq!(tools.len(), 8);
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

        let src = r#"{"source":"FUNCTION_BLOCK C VAR_INPUT x : BOOL; END_VAR VAR n : INT; END_VAR IF x THEN n := n + 1; END_IF; END_FUNCTION_BLOCK\nTEST t VAR c : C; END_VAR c(x := TRUE); ASSERT_EQ(1, c.n); END_TEST"}"#;
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

        let src = r#"{"source":"FUNCTION_BLOCK A VAR_INPUT s, k : BOOL; END_VAR VAR_OUTPUT q : BOOL; END_VAR IF NOT k THEN q := FALSE; ELSIF s THEN q := TRUE; END_IF; END_FUNCTION_BLOCK
FUNCTION_BLOCK B VAR_INPUT s, k : BOOL; END_VAR VAR_OUTPUT q : BOOL; END_VAR IF s THEN q := TRUE; ELSIF NOT k THEN q := FALSE; END_IF; END_FUNCTION_BLOCK","reference":"A","unit":"B"}"#;
        let rep = tool("rootplc_diff", src);
        assert_eq!(rep.get("verdict").and_then(Json::as_str), Some("differ"));
        assert_eq!(rep.get("ok"), Some(&Json::Bool(false)));
        let src = src.replace(
            r#""unit":"B""#,
            r#""unit":"B","set":["k=TRUE"],"cycles":200"#,
        );
        let rep = tool("rootplc_diff", &src);
        assert_eq!(rep.get("verdict").and_then(Json::as_str), Some("agree"));
        assert_eq!(rep.get("cycles").and_then(Json::as_f64), Some(200.0));
        let rep = tool(
            "rootplc_diff",
            r#"{"source":"FUNCTION_BLOCK A END_FUNCTION_BLOCK","reference":"A","unit":"Z"}"#,
        );
        assert_eq!(rep.get("ok"), Some(&Json::Bool(false)));

        let rep = tool("rootplc_explain", r#"{"code":"103"}"#);
        assert_eq!(
            rep.get("rule").and_then(Json::as_str),
            Some("types.conversion.implicit")
        );
        let rep = tool("rootplc_check", "{}");
        assert_eq!(rep.get("ok"), Some(&Json::Bool(false)));

        let rep = tool("rootplc_examples", r#"{"query":"timer"}"#);
        let ex = rep
            .get("examples")
            .and_then(Json::as_array)
            .expect("examples");
        assert_eq!(ex[0].get("id").and_then(Json::as_str), Some("on-off-delay"));
        assert!(ex[0].get("source").and_then(Json::as_str).is_some());
        let rep = tool("rootplc_examples", r#"{"id":"nope"}"#);
        assert_eq!(rep.get("ok"), Some(&Json::Bool(false)));

        let rep = tool(
            "rootplc_coverage",
            r#"{"source":"PROGRAM p VAR r : REF_TO INT; END_VAR r := __NEW(INT); END_PROGRAM"}"#,
        );
        assert_eq!(rep.get("dialect").and_then(Json::as_f64), Some(1.0));
    }

    #[test]
    fn resources_and_prompts() {
        let r = call(r#"{"jsonrpc":"2.0","id":3,"method":"resources/list"}"#);
        let list = r
            .get("result")
            .and_then(|x| x.get("resources"))
            .and_then(Json::as_array)
            .expect("resources");
        assert!(list.len() >= 10);
        for res in list {
            let uri = res.get("uri").and_then(Json::as_str).expect("uri");
            let r = call(&format!(
                r#"{{"jsonrpc":"2.0","id":4,"method":"resources/read","params":{{"uri":"{uri}"}}}}"#
            ));
            let text = r
                .get("result")
                .and_then(|x| x.get("contents"))
                .and_then(Json::as_array)
                .and_then(|c| c[0].get("text"))
                .and_then(Json::as_str);
            assert!(text.is_some_and(|t| !t.is_empty()), "{uri}");
        }
        let r = call(
            r#"{"jsonrpc":"2.0","id":5,"method":"resources/read","params":{"uri":"rootplc://none"}}"#,
        );
        assert!(r.get("error").is_some());

        let r = call(r#"{"jsonrpc":"2.0","id":6,"method":"prompts/list"}"#);
        let prompts = r
            .get("result")
            .and_then(|x| x.get("prompts"))
            .and_then(Json::as_array)
            .expect("prompts");
        assert_eq!(prompts.len(), 3);
        let r = call(
            r#"{"jsonrpc":"2.0","id":7,"method":"prompts/get","params":{"name":"port_legacy","arguments":{"path":"src"}}}"#,
        );
        let text = r
            .get("result")
            .and_then(|x| x.get("messages"))
            .and_then(Json::as_array)
            .and_then(|m| m[0].get("content"))
            .and_then(|c| c.get("text"))
            .and_then(Json::as_str)
            .expect("prompt text");
        assert!(text.contains("rootplc_coverage") && text.contains("src"));
    }
}
