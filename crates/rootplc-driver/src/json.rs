//! JSON reports shared by the CLI (`--json`) and the MCP server. One object
//! per command; positions are 1-based lines and columns (columns in
//! characters).

use rootplc_diag::{json_string, line_col};

use crate::coverage::{CoverageReport, Status};
use crate::examples::Example;
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
        .filter(|f| !f.library)
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
        r.files.iter().filter(|f| !f.library).count(),
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
    let tests: Vec<String> = r
        .tests
        .iter()
        .map(|t| {
            let status = ["passed", "failed", "skipped"][usize::from(t.status.min(2))];
            format!(
                "{{\"suite\":{},\"test\":{},\"status\":\"{status}\",\"message\":{}}}",
                json_string(&t.suite),
                json_string(&t.test),
                json_string(&t.message)
            )
        })
        .collect();
    format!(
        "{{\"command\":\"run\",\"ok\":{},\"program\":{},\"cycles\":{},\"fault\":{},\"diagnostics\":{},\"variables\":{{{}}},\"tests\":[{}]}}",
        r.ok(),
        json_string(&r.program),
        r.cycles,
        fault(&r.check, r.fault.as_ref()),
        diagnostics(&r.check),
        vars.join(","),
        tests.join(",")
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

/// `examples` report. `with_source` adds the full code of each example.
pub fn examples(query: &str, found: &[Example], with_source: bool) -> String {
    let items: Vec<String> = found
        .iter()
        .map(|e| {
            let tags: Vec<String> = e.tags.iter().map(|t| json_string(t)).collect();
            let source = if with_source {
                format!(",\"source\":{}", json_string(e.source))
            } else {
                String::new()
            };
            format!(
                "{{\"id\":{},\"title\":{},\"tags\":[{}],\"description\":{}{source}}}",
                json_string(e.id),
                json_string(&e.title),
                tags.join(","),
                json_string(&e.description)
            )
        })
        .collect();
    format!(
        "{{\"command\":\"examples\",\"ok\":true,\"query\":{},\"verified\":true,\"count\":{},\"examples\":[{}]}}",
        json_string(query),
        found.len(),
        items.join(",")
    )
}

/// `coverage` report.
pub fn coverage(r: &CoverageReport) -> String {
    let units: Vec<String> = r
        .units
        .iter()
        .map(|u| {
            let codes: Vec<String> = u.codes.iter().map(|c| json_string(c)).collect();
            let cons: Vec<String> = u
                .constructs
                .iter()
                .map(|c| {
                    format!(
                        "{{\"name\":{},\"standard\":\"{}\",\"line\":{},\"count\":{}}}",
                        json_string(c.name),
                        if c.iec { "iec-ed3" } else { "vendor" },
                        c.line,
                        c.count
                    )
                })
                .collect();
            let deps: Vec<String> = u
                .blocked_by
                .iter()
                .map(|p| json_string(&p.display().to_string()))
                .collect();
            format!(
                "{{\"file\":{},\"status\":\"{}\",\"errors\":{},\"codes\":[{}],\"constructs\":[{}],\"blocked_by\":[{}]}}",
                json_string(&u.path.display().to_string()),
                u.status.name(),
                u.errors,
                codes.join(","),
                cons.join(","),
                deps.join(",")
            )
        })
        .collect();
    format!(
        "{{\"command\":\"coverage\",\"ok\":true,\"units\":{},\"portable\":{},\"dialect\":{},\"dependent\":{},\"blocked\":{},\"files\":[{}]}}",
        r.units.len(),
        r.count(Status::Portable),
        r.count(Status::Dialect),
        r.count(Status::Dependent),
        r.count(Status::Blocked),
        units.join(",")
    )
}

/// `libraries` report: the bundled compatibility libraries.
pub fn libraries() -> String {
    let items: Vec<String> = rootplc_stdlib::compat::libraries()
        .iter()
        .map(|l| {
            let list = |v: &[String]| v.iter().map(|x| json_string(x)).collect::<Vec<_>>().join(",");
            format!(
                "{{\"name\":{},\"vendor\":{},\"version\":{},\"description\":{},\"declare_only\":[{}],\"references\":[{}]}}",
                json_string(&l.name),
                json_string(&l.vendor),
                json_string(&l.version),
                json_string(&l.description),
                list(&l.declare_only),
                list(&l.references)
            )
        })
        .collect();
    format!(
        "{{\"command\":\"libraries\",\"ok\":true,\"libraries\":[{}]}}",
        items.join(",")
    )
}

/// A command that could not run (bad arguments, unreadable file).
pub fn error(command: &str, message: &str) -> String {
    format!(
        "{{\"command\":\"{command}\",\"ok\":false,\"status\":\"error\",\"message\":{}}}",
        json_string(message)
    )
}
