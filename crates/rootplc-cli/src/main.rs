//! The `rootplc` binary. Argument parsing and output formatting only;
//! every command is implemented in `rootplc-driver`.

use rootplc_diag::Severity;
use rootplc_driver::{CheckReport, Command, json};
use std::path::PathBuf;
use std::process::ExitCode;

const USAGE: &str = "usage:
  rootplc init  [dir] [--name NAME] [--agent claude|gemini|qwen|cursor|codex|all]
  rootplc check <file.st|dir>... [--json]
  rootplc test  <file.st|dir>... [--filter TEXT] [--slice] [--json]   (--slice: only the files the tests need)
  rootplc test  <file.st|dir>... --mutate [--mutate-limit N] [--mutate-only TEXT] [--min-score P] [--json]
                (mutation score of the tests; --mutate-only: mutate only files whose path contains TEXT)
  rootplc run   <file.st|dir>... [--program NAME] [--cycles N] [--cycle-ms MS] [--json]
  rootplc diff  <file.st|dir>... --reference FB --unit FB [--cycles N] [--cycle-ms MS] [--seed N]
                [--set NAME=VALUE]... [--range NAME=LO..HI]... [--toggle P] [--tolerance T] [--json]
                (same stimuli to both blocks, outputs compared each cycle; exit 1 when they differ)
  rootplc build <file.st|dir>... --target c --out DIR [--program NAME] [--json]
                (one portable C99 file that computes what the VM computes)
  rootplc sim   <file.st|dir>... --scenario FILE [--trace OUT.csv] [--compare OLD.csv] [--json]
                (programs and plant models on the virtual clock; expectations; CSV trace)
  rootplc runtime <file.st|dir>... [--program NAME] [--cycle-ms MS] [--cycles N] [--watchdog-ms MS]
                [--retain FILE] [--status FILE] [--modbus [ADDR:]PORT] [--deploy DIR] [--json]   (runtime v0)
  rootplc deploy <file.st|dir>... --to DIR [--program NAME]   (request; runs only after approval)
  rootplc approve DIR [--rollback]          (a person approves at the runtime's terminal)
  rootplc evidence <file.st|dir>... [--out FILE] [--markdown] [--no-mutate] [--min-score P]   (evidence pack for sign-off)
  rootplc explain <code> [--json]
  rootplc examples [words...] [--show ID] [--json]   (verified ST patterns)
  rootplc coverage <file.st|dir>... [--json]
  rootplc libraries [--json]                       (bundled compatibility libraries)
  check, test, diff, run, sim, runtime and coverage take --library NAME[,NAME] (e.g. Tc2_System)       (portable / dialect / dependent / blocked)
  rootplc mcp            (MCP server on stdio, for agent hosts)
  rootplc lsp            (Language Server Protocol on stdio, for editors)
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
                "--mutate" | "--markdown" | "--no-mutate" | "--rollback" | "--slice" => {
                    a.options.push((x, String::new()))
                }
                "--program" | "--cycles" | "--cycle-ms" | "--filter" | "--name" | "--show"
                | "--agent" | "--library" | "--mutate-limit" | "--mutate-only" | "--min-score"
                | "--out" | "--watchdog-ms" | "--retain" | "--status" | "--modbus" | "--deploy"
                | "--to" | "--reference" | "--unit" | "--seed" | "--set" | "--range"
                | "--toggle" | "--tolerance" | "--scenario" | "--trace" | "--compare"
                | "--target" => {
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

fn cmd_evidence(paths: &[PathBuf], args: &Args) -> ExitCode {
    let sources = match rootplc_driver::read_sources(paths) {
        Ok(s) => s,
        Err(e) => return io_error("evidence", &e, false),
    };
    let opts = rootplc_driver::evidence::Options {
        libraries: args.all("--library"),
        mutate: args.opt("--no-mutate").is_none(),
        mutate_limit: args
            .opt("--mutate-limit")
            .and_then(|v| v.parse().ok())
            .unwrap_or(rootplc_driver::mutate::DEFAULT_LIMIT),
        min_score: args.opt("--min-score").and_then(|v| v.parse().ok()),
    };
    let e = match rootplc_driver::evidence::evidence(sources, &opts) {
        Ok(e) => e,
        Err(msg) => return io_error("evidence", &msg, false),
    };
    let text = if args.opt("--markdown").is_some() {
        rootplc_driver::evidence::to_markdown(&e)
    } else {
        rootplc_driver::evidence::to_json(&e)
            + "
"
    };
    match args.opt("--out") {
        Some(path) => {
            if let Err(err) = std::fs::write(path, text) {
                return io_error("evidence", &format!("{path}: {err}"), false);
            }
            eprintln!(
                "wrote {path}: {}",
                if e.verified() {
                    "verified".to_string()
                } else {
                    format!("not verified ({})", e.reasons.join("; "))
                }
            );
        }
        None => print!("{text}"),
    }
    exit(e.verified())
}

fn cmd_mutate(paths: &[PathBuf], filter: Option<&str>, args: &Args) -> ExitCode {
    let json_out = args.json;
    let sources = match rootplc_driver::read_sources(paths) {
        Ok(s) => s,
        Err(e) => return io_error("test", &e, json_out),
    };
    let limit = args
        .opt("--mutate-limit")
        .and_then(|v| v.parse().ok())
        .unwrap_or(rootplc_driver::mutate::DEFAULT_LIMIT);
    let min_score: Option<f64> = args.opt("--min-score").and_then(|v| v.parse().ok());
    let sources = sliced(sources, args);
    let r = match rootplc_driver::mutate::mutation_report_only(
        sources,
        &args.all("--library"),
        filter,
        limit,
        args.opt("--mutate-only"),
    ) {
        Ok(r) => r,
        Err(e) => return io_error("test", &e, json_out),
    };
    let ok = json::mutation_ok(&r, min_score);
    if json_out {
        println!("{}", json::mutation(&r, min_score));
        return exit(ok);
    }
    if let Some(e) = &r.error {
        print_diagnostics(&r.baseline.check);
        eprintln!("rootplc test --mutate: {e}");
        return exit(false);
    }
    for m in r.survivors() {
        let shown = if m.replacement.is_empty() {
            "removed".to_string()
        } else {
            format!("'{}'", m.replacement)
        };
        println!(
            "SURVIVED {}:{}:{}: '{}' -> {shown}",
            m.path.display(),
            m.line,
            m.column,
            m.original
        );
    }
    let not_viable = r.mutants.len() - r.viable();
    match r.score() {
        Some(s) => eprintln!(
            "mutation score {:.0}%: {} of {} viable mutants killed ({} not viable{})",
            s * 100.0,
            r.killed(),
            r.viable(),
            not_viable,
            if r.candidates > r.mutants.len() {
                format!("; {} of {} candidates run", r.mutants.len(), r.candidates)
            } else {
                String::new()
            }
        ),
        None => eprintln!("no viable mutants ({not_viable} not viable)"),
    }
    if let (Some(m), false) = (min_score, ok) {
        eprintln!("below the required score of {m}%");
    }
    exit(ok)
}

/// With `--slice`, only the files the TEST blocks need ([tests.slice]).
fn sliced(sources: Vec<(PathBuf, String)>, args: &Args) -> Vec<(PathBuf, String)> {
    if args.opt("--slice").is_none() {
        return sources;
    }
    let (kept, left) = rootplc_driver::slice::slice_tests(sources);
    if !left.is_empty() {
        eprintln!(
            "--slice: {} file(s) left out (not needed by the tests)",
            left.len()
        );
    }
    kept
}

fn cmd_test(paths: &[PathBuf], filter: Option<&str>, args: &Args) -> ExitCode {
    if args.opt("--mutate").is_some() {
        return cmd_mutate(paths, filter, args);
    }
    let json_out = args.json;
    let sources = match rootplc_driver::read_sources(paths) {
        Ok(s) => s,
        Err(e) => return io_error("test", &e, json_out),
    };
    let sources = sliced(sources, args);
    let r = match rootplc_driver::check_sources_with(sources, &args.all("--library")) {
        Ok(c) => rootplc_driver::test_report(c, filter),
        Err(e) => return io_error("test", &e, json_out),
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
        for l in &r.log {
            println!("log {} {}: {}", l.cycle, l.mask, l.text);
        }
        if let Some(f) = &r.fault {
            let (n, l, c) = json::location(&r.check, f.file, f.span.start);
            println!("{n}:{l}:{c}: fault {}: {}", f.kind.name(), f.message);
        }
    }
    exit(r.ok())
}

fn cmd_diff(paths: &[PathBuf], args: &Args) -> ExitCode {
    use rootplc_driver::diff::{DiffOptions, DiffRun, Verdict, diff_sources, render, to_json};
    let mut opt = DiffOptions::default();
    let (Some(reference), Some(unit)) = (args.opt("--reference"), args.opt("--unit")) else {
        return io_error("diff", "give --reference FB and --unit FB", args.json);
    };
    opt.reference = reference.to_string();
    opt.unit = unit.to_string();
    macro_rules! num {
        ($name:literal, $field:ident) => {
            if let Some(v) = args.opt($name) {
                match v.parse() {
                    Ok(x) => opt.$field = x,
                    Err(_) => {
                        return io_error(
                            "diff",
                            &format!("{}: not a number: {v}", $name),
                            args.json,
                        );
                    }
                }
            }
        };
    }
    num!("--cycles", cycles);
    num!("--cycle-ms", cycle_ms);
    num!("--seed", seed);
    num!("--toggle", toggle);
    num!("--tolerance", tolerance);
    for s in args.all("--set") {
        let Some((n, v)) = s.split_once('=') else {
            return io_error("diff", &format!("--set {s}: write NAME=VALUE"), args.json);
        };
        opt.set.push((n.trim().to_string(), v.trim().to_string()));
    }
    for s in args.all("--range") {
        let parsed = s.split_once('=').and_then(|(n, r)| {
            let (lo, hi) = r.split_once("..")?;
            Some((
                n.trim().to_string(),
                lo.trim().parse().ok()?,
                hi.trim().parse().ok()?,
            ))
        });
        match parsed {
            Some(r) => opt.ranges.push(r),
            None => {
                return io_error(
                    "diff",
                    &format!("--range {s}: write NAME=LO..HI"),
                    args.json,
                );
            }
        }
    }
    let sources = match rootplc_driver::read_sources(paths) {
        Ok(s) => s,
        Err(e) => return io_error("diff", &e, args.json),
    };
    let r = match diff_sources(sources, &args.all("--library"), &opt) {
        Ok(DiffRun::Report(r)) => *r,
        Ok(DiffRun::NotCompiling(check)) => {
            if args.json {
                println!("{}", json::check(&check));
            } else {
                print_diagnostics(&check);
                eprintln!("rootplc diff: the files the blocks need do not compile");
            }
            return ExitCode::from(2);
        }
        Err(e) => return io_error("diff", &e, args.json),
    };
    if args.json {
        println!("{}", to_json(&r));
    } else {
        print!("{}", render(&r));
    }
    exit(r.verdict == Verdict::Agree)
}

/// `rootplc build --target c` ([build.c.command]).
fn cmd_build(paths: &[PathBuf], args: &Args) -> ExitCode {
    use rootplc_driver::build::{build_c, to_json};
    match args.opt("--target") {
        Some("c") => {}
        Some(t) => {
            return io_error(
                "build",
                &format!("unknown target '{t}' (only c so far)"),
                args.json,
            );
        }
        None => return io_error("build", "give --target c", args.json),
    }
    let Some(out) = args.opt("--out") else {
        return io_error("build", "give --out DIR", args.json);
    };
    let check = match load("build", paths, args) {
        Ok(c) => c,
        Err(code) => return code,
    };
    let r = match build_c(check, args.opt("--program")) {
        Ok(r) => r,
        Err(e) => return io_error("build", &e, args.json),
    };
    let file = PathBuf::from(out).join("rootplc_program.c");
    if let Some(code) = &r.code {
        if let Err(e) = std::fs::create_dir_all(out).and_then(|()| std::fs::write(&file, code)) {
            return io_error("build", &format!("{}: {e}", file.display()), args.json);
        }
    }
    if args.json {
        println!("{}", to_json(&r, &file.display().to_string()));
    } else {
        print_diagnostics(&r.check);
        if !r.check.ok() {
            eprintln!("rootplc build: the project does not compile");
        } else if let Some(u) = &r.unsupported {
            println!(
                "{}:{}:{}: not supported by the C back end yet: {}",
                u.file, u.line, u.column, u.construct
            );
        } else {
            println!("{}: wrote {}", r.program, file.display());
        }
    }
    if !r.check.ok() {
        ExitCode::from(1)
    } else if r.unsupported.is_some() {
        ExitCode::from(2)
    } else {
        ExitCode::SUCCESS
    }
}

/// `rootplc sim` ([sim.command]).
fn cmd_sim(paths: &[PathBuf], args: &Args) -> ExitCode {
    use rootplc_driver::sim::{SimRun, render, sim_sources, to_json, trace_csv};
    let Some(scenario) = args.opt("--scenario") else {
        return io_error("sim", "give --scenario FILE", args.json);
    };
    let text = match std::fs::read_to_string(scenario) {
        Ok(t) => t,
        Err(e) => return io_error("sim", &format!("{scenario}: {e}"), args.json),
    };
    let old = match args
        .opt("--compare")
        .map(std::fs::read_to_string)
        .transpose()
    {
        Ok(t) => t,
        Err(e) => return io_error("sim", &format!("--compare: {e}"), args.json),
    };
    let sources = match rootplc_driver::read_sources(paths) {
        Ok(s) => s,
        Err(e) => return io_error("sim", &e, args.json),
    };
    let r = match sim_sources(sources, &args.all("--library"), &text, old.as_deref()) {
        Ok(SimRun::Report(r)) => *r,
        Ok(SimRun::NotCompiling(check)) => {
            if args.json {
                println!("{}", json::check(&check));
            } else {
                print_diagnostics(&check);
                eprintln!("rootplc sim: the project does not compile");
            }
            return ExitCode::from(2);
        }
        Err(e) => return io_error("sim", &e, args.json),
    };
    if let Some(out) = args.opt("--trace") {
        if let Err(e) = std::fs::write(out, trace_csv(&r.trace)) {
            return io_error("sim", &format!("--trace {out}: {e}"), args.json);
        }
    }
    if args.json {
        println!("{}", to_json(&r));
    } else {
        print_diagnostics(&r.check);
        print!("{}", render(&r));
    }
    exit(r.ok())
}

fn cmd_runtime(paths: &[PathBuf], args: &Args) -> ExitCode {
    use rootplc_runtime::{Config, NoIo, State, SystemClock, ffi, to_json, to_text};
    let num = |name: &str| args.opt(name).and_then(|v| v.parse::<u64>().ok());
    let mut config = Config::with_period_ms(num("--cycle-ms").unwrap_or(10));
    if let Some(ms) = num("--watchdog-ms") {
        config.watchdog_ns = ms.max(1) * 1_000_000;
    }
    config.cycles = num("--cycles");
    config.retain = args.opt("--retain").map(PathBuf::from);
    config.status = args.opt("--status").map(PathBuf::from);
    let check = match load("runtime", paths, args) {
        Ok(c) => c,
        Err(code) => return code,
    };
    if !check.ok() {
        print_diagnostics(&check);
        return ExitCode::from(1);
    }
    let deploy_dir = args.opt("--deploy").map(PathBuf::from);
    let libraries = library_list(args);
    let stop = ffi::stop_on_interrupt();
    if !args.json && config.cycles.is_none() {
        eprintln!(
            "rootplc runtime: running every {} ms; Ctrl-C stops",
            config.period_ns / 1_000_000
        );
    }
    let opts = rootplc_driver::runtime::RunOptions {
        program: args.opt("--program"),
        config,
        modbus: args.opt("--modbus"),
        deploy: deploy_dir.as_deref().map(|d| (d, libraries.as_slice())),
    };
    let report = match rootplc_driver::runtime::run_runtime(
        &check,
        opts,
        NoIo,
        SystemClock::default(),
        stop,
    ) {
        Ok(r) => r,
        Err(e) => return io_error("runtime", &e, args.json),
    };
    if args.json {
        println!("{}", to_json(&report));
    } else {
        print!("{}", to_text(&report));
    }
    exit(!matches!(report.state, State::Fault(_)))
}

/// The `--library` names, split at commas.
fn library_list(args: &Args) -> Vec<String> {
    args.all("--library")
        .iter()
        .flat_map(|l| l.split(','))
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty())
        .collect()
}

fn cmd_deploy(paths: &[PathBuf], args: &Args) -> ExitCode {
    let Some(dir) = args.opt("--to").map(PathBuf::from) else {
        return io_error(
            "deploy",
            "give the runtime's deploy directory with --to DIR",
            args.json,
        );
    };
    let check = match load("deploy", paths, args) {
        Ok(c) => c,
        Err(code) => return code,
    };
    print_diagnostics(&check);
    let tests = rootplc_driver::test_report(check, None);
    let libraries = library_list(args);
    match rootplc_driver::deploy::make_request(&dir, &tests, args.opt("--program"), &libraries) {
        Ok(r) => {
            println!(
                "deploy request {} written to {}: {} file(s), {} test(s) passed.",
                r.code,
                dir.display(),
                r.files.len(),
                r.tests.0
            );
            println!(
                "Nothing runs until a person approves it at the runtime: rootplc approve {}",
                dir.display()
            );
            ExitCode::SUCCESS
        }
        Err(e) => io_error("deploy", &e, args.json),
    }
}

fn cmd_approve(dir: Option<&String>, args: &Args) -> ExitCode {
    use rootplc_driver::deploy;
    use std::io::{BufRead, IsTerminal};
    let Some(dir) = dir.map(PathBuf::from) else {
        return io_error("approve", "give the runtime's deploy directory", false);
    };
    // [runtime.deploy]: a person approves at a terminal; an agent running
    // commands without one cannot approve its own deployment
    if !std::io::stdin().is_terminal() {
        return io_error(
            "approve",
            "approval needs a person at a terminal; standard input is not a terminal",
            false,
        );
    }
    if args.opt("--rollback").is_some() {
        if let Err(e) = deploy::rollback_request(&dir) {
            return io_error("approve", &e, false);
        }
    }
    let pending = deploy::list(&dir, "pending");
    if pending.is_empty() {
        println!("no pending deploy requests in {}", dir.display());
        return ExitCode::SUCCESS;
    }
    for r in &pending {
        let program = if r.program.is_empty() {
            "(the only PROGRAM)"
        } else {
            r.program.as_str()
        };
        println!(
            "request {}  program {program}  tests passed {}",
            r.code, r.tests.0
        );
        for (n, h) in &r.files {
            println!("    {n}  sha256 {}", &h[..16]);
        }
        if let Err(e) = deploy::verify(r) {
            println!("    WARNING: {e}");
        }
    }
    println!("Type the code of the request to approve (Enter cancels):");
    let mut line = String::new();
    let _ = std::io::stdin().lock().read_line(&mut line);
    let code = line.trim();
    if code.is_empty() {
        println!("nothing approved");
        return ExitCode::SUCCESS;
    }
    match deploy::approve(&dir, code) {
        Ok(r) => {
            println!(
                "approved {}; the runtime swaps it in within a second (see audit.log)",
                r.code
            );
            ExitCode::SUCCESS
        }
        Err(e) => io_error("approve", &e, false),
    }
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
        let needs = if e.libraries.is_empty() {
            String::new()
        } else {
            format!(" (needs --library {})", e.libraries.join(","))
        };
        println!(
            "{:<22} {}{needs}
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
    if first == "lsp" {
        return match rootplc_mcp::lsp::serve_stdio() {
            Ok(()) => ExitCode::SUCCESS,
            Err(e) => io_error("lsp", &e.to_string(), false),
        };
    }
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
        Some(
            Command::Check
                | Command::Test
                | Command::Run
                | Command::Diff
                | Command::Sim
                | Command::Build
                | Command::Runtime
                | Command::Deploy
                | Command::Coverage
                | Command::Evidence
        )
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
        Some(Command::Diff) => cmd_diff(&paths, &args),
        Some(Command::Sim) => cmd_sim(&paths, &args),
        Some(Command::Build) => cmd_build(&paths, &args),
        Some(Command::Runtime) => cmd_runtime(&paths, &args),
        Some(Command::Deploy) => cmd_deploy(&paths, &args),
        Some(Command::Approve) => cmd_approve(rest.first(), &args),
        Some(Command::Explain) => cmd_explain(rest.first(), args.json),
        Some(Command::Init) => cmd_init(rest.first(), args.opt("--name"), args.opt("--agent")),
        Some(Command::Examples) => cmd_examples(rest, &args),
        Some(Command::Coverage) => cmd_coverage(&paths, &args),
        Some(Command::Evidence) => cmd_evidence(&paths, &args),
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
