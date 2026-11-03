//! JSON reports shared by the CLI (`--json`) and the MCP server. One object
//! per command; positions are 1-based lines and columns (columns in
//! characters).

use rootplc_diag::{json_string, line_col};

use crate::explain::Explanation;
use crate::{CheckReport, RunReport, TestReport};

/// File name and 1-based position of a location reported by the VM
/// (`file` is an IR file index).
pub fn location(report: &CheckReport, file: usize, offset: u32) -> (String, usize, usize) {
    match report.ir_files.get(file).and_then(|&i| report.files.get(i)) {
        Some(f) => {
            let (l, c) = line_col(&f.source, offset);
            (f.path.display().to_string(), l, c)
        }
        None => (String::from("?"), 0, 0),
    }
}

fn located(report: &CheckReport, file: usize, offset: u32, extra: &str) -> String {
    let (name, l, c) = location(report, file, offset);
    format!(
        "{{\"file\":{},\"line\":{l},\"column\":{c},{extra}}}",
        json_string(&name)
    )
}

fn fault(report: &CheckReport, f: Option<&rootplc_vm::Fault>) -> String {
    f.map_or("null".to_string(), |f| {
        let extra = format!(
            "\"kind\":\"{}\",\"message\":{}",
            f.kind.name(),
            json_string(&f.message)
        );
        located(report, f.file, f.span.start, &extra)
    })
}

fn diagnostics(report: &CheckReport) -> String {
    let items: Vec<String> = report
        .files
        .iter()
        .flat_map(|f| {
            let name = f.path.display().to_string();
            f.diagnostics
                .iter()
                .map(move |d| d.render_json(&name, &f.source))
        })
        .collect();
    format!("[{}]", items.join(","))
}

/// `check` report.
pub fn check(r: &CheckReport) -> String {
    use rootplc_diag::Severity;
    format!(
        "{{\"command\":\"check\",\"ok\":{},\"files\":{},\"errors\":{},\"warnings\":{},\"diagnostics\":{}}}",
        r.ok(),
        r.files.len(),
        r.count(Severity::Error),
        r.count(Severity::Warning),
        diagnostics(r)
    )
}

/// `test` report.
pub fn test(r: &TestReport) -> String {
    let passed = r.outcomes.iter().filter(|o| o.passed()).count();
    let tests: Vec<String> = r
        .outcomes
        .iter()
        .map(|o| {
            let failures: Vec<String> = o
                .failures
                .iter()
                .map(|f| {
                    located(
                        &r.check,
                        f.file,
                        f.span.start,
                        &format!("\"message\":{}", json_string(&f.message)),
                    )
                })
                .collect();
            format!(
                "{{\"name\":{},\"passed\":{},\"failures\":[{}],\"fault\":{}}}",
                json_string(&o.name),
                o.passed(),
                failures.join(","),
                fault(&r.check, o.fault.as_ref())
            )
        })
        .collect();
    format!(
        "{{\"command\":\"test\",\"ok\":{},\"compiled\":{},\"passed\":{passed},\"failed\":{},\"diagnostics\":{},\"tests\":[{}]}}",
        r.ok(),
        r.check.ok(),
        r.outcomes.len() - passed,
        diagnostics(&r.check),
        tests.join(",")
    )
}

/// `run` report.
pub fn run(r: &RunReport) -> String {
    let vars: Vec<String> = r
        .variables
        .iter()
        .map(|(n, v)| format!("{}:{}", json_string(n), json_string(v)))
        .collect();
    format!(
        "{{\"command\":\"run\",\"ok\":{},\"program\":{},\"cycles\":{},\"fault\":{},\"diagnostics\":{},\"variables\":{{{}}}}}",
        r.ok(),
        json_string(&r.program),
        r.cycles,
        fault(&r.check, r.fault.as_ref()),
        diagnostics(&r.check),
        vars.join(",")
    )
}

/// `explain` report.
pub fn explain(e: &Explanation) -> String {
    format!(
        "{{\"command\":\"explain\",\"ok\":true,\"code\":\"{}\",\"severity\":\"{}\",\"summary\":{},\"rule\":{},\"spec\":{},\"text\":{}}}",
        e.code,
        e.severity,
        json_string(&e.summary),
        json_string(&e.rule),
        json_string(&e.file),
        json_string(&e.text)
    )
}

/// A command that could not run (bad arguments, unreadable file).
pub fn error(command: &str, message: &str) -> String {
    format!(
        "{{\"command\":\"{command}\",\"ok\":false,\"status\":\"error\",\"message\":{}}}",
        json_string(message)
    )
}
