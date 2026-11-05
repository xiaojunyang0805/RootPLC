//! Approval-gated deploy for runtime v0 ([runtime.deploy]).
//!
//! Layout of a deploy directory:
//! - `pending/<code>/`, `approved/<code>/`, `rejected/<code>/`: requests;
//! - `current/`, `previous/`: the running and the replaced program;
//! - `audit.log`: one line per event (UTC time, event, code, detail).
//!
//! A request holds `manifest.txt` and the sources under `src/`. The code is
//! the first eight hex digits of the SHA-256 over the file names and hashes.

use std::path::{Path, PathBuf};

use rootplc_runtime::Updates;

use crate::runtime::VmProgram;
use crate::{CheckReport, TestReport, check_sources_with, sha256};

/// Format line of a manifest.
pub const FORMAT: &str = "rootplc-deploy/0";

/// One deploy request, as read from its manifest.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Request {
    /// Directory of the request.
    pub dir: PathBuf,
    /// Eight hex digits.
    pub code: String,
    /// SHA-256 over all files.
    pub sha256: String,
    /// PROGRAM to run (empty: the only one).
    pub program: String,
    /// Bundled libraries to activate.
    pub libraries: Vec<String>,
    /// Tests passed and failed when the request was made.
    pub tests: (usize, usize),
    /// Files: stored name and SHA-256.
    pub files: Vec<(String, String)>,
}

fn total_hash(files: &[(String, String)]) -> String {
    let mut all = String::new();
    for (n, h) in files {
        all.push_str(n);
        all.push('\n');
        all.push_str(h);
        all.push('\n');
    }
    sha256::hex(all.as_bytes())
}

/// The user name of this account, for the audit log.
pub fn user_name() -> String {
    std::env::var("USER")
        .or_else(|_| std::env::var("USERNAME"))
        .unwrap_or_else(|_| "unknown".into())
}

/// UTC time as `YYYY-MM-DDTHH:MM:SSZ`.
pub fn utc_now() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_or(0, |d| d.as_secs()) as i64;
    let (days, rem) = (secs.div_euclid(86_400), secs.rem_euclid(86_400));
    // civil date from days since 1970-01-01 (Howard Hinnant's algorithm)
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let y = yoe + era * 400 + i64::from(m <= 2);
    format!(
        "{y:04}-{m:02}-{d:02}T{:02}:{:02}:{:02}Z",
        rem / 3600,
        rem / 60 % 60,
        rem % 60
    )
}

/// Append one line to `DIR/audit.log`.
pub fn audit(dir: &Path, event: &str, code: &str, detail: &str) {
    use std::io::Write;
    let line = format!("{}\t{event}\t{code}\t{detail}\n", utc_now());
    if let Ok(mut f) = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(dir.join("audit.log"))
    {
        let _ = f.write_all(line.as_bytes());
    }
}

/// Write the project's sources and manifest into `to` (a new directory).
fn write_bundle(
    to: &Path,
    check: &CheckReport,
    program: Option<&str>,
    libraries: &[String],
    tests: (usize, usize),
) -> Result<Request, String> {
    let err = |e: std::io::Error| format!("{}: {e}", to.display());
    std::fs::create_dir_all(to.join("src")).map_err(err)?;
    let mut files = Vec::new();
    for (i, f) in check.files.iter().filter(|f| !f.library).enumerate() {
        let base = f
            .path
            .file_name()
            .map_or("file.st".into(), |n| n.to_string_lossy().to_string());
        let name = format!("{i:03}_{base}");
        std::fs::write(to.join("src").join(&name), &f.source).map_err(err)?;
        files.push((name, sha256::hex(f.source.as_bytes())));
    }
    let sha = total_hash(&files);
    let code = sha[..8].to_string();
    let mut m = format!(
        "format\t{FORMAT}\ncode\t{code}\nsha256\t{sha}\nprogram\t{}\nlibraries\t{}\ntests\t{}\t{}\n",
        program.unwrap_or(""),
        libraries.join(","),
        tests.0,
        tests.1
    );
    for (n, h) in &files {
        m.push_str(&format!("file\t{n}\t{h}\n"));
    }
    std::fs::write(to.join("manifest.txt"), m).map_err(err)?;
    read_request(to)
}

/// Read a request's manifest.
pub fn read_request(dir: &Path) -> Result<Request, String> {
    let text = std::fs::read_to_string(dir.join("manifest.txt"))
        .map_err(|e| format!("{}: {e}", dir.display()))?;
    let mut r = Request {
        dir: dir.to_path_buf(),
        code: String::new(),
        sha256: String::new(),
        program: String::new(),
        libraries: Vec::new(),
        tests: (0, 0),
        files: Vec::new(),
    };
    let mut format_ok = false;
    for line in text.lines() {
        let f: Vec<&str> = line.split('\t').collect();
        match f.as_slice() {
            ["format", v] => format_ok = *v == FORMAT,
            ["code", v] => r.code = (*v).into(),
            ["sha256", v] => r.sha256 = (*v).into(),
            ["program", v] => r.program = (*v).into(),
            ["libraries", v] => {
                r.libraries = v
                    .split(',')
                    .filter(|s| !s.is_empty())
                    .map(Into::into)
                    .collect();
            }
            ["tests", p, q] => r.tests = (p.parse().unwrap_or(0), q.parse().unwrap_or(0)),
            ["file", n, h] => r.files.push(((*n).into(), (*h).into())),
            _ => {}
        }
    }
    if !format_ok {
        return Err(format!("{}: not a {FORMAT} manifest", dir.display()));
    }
    Ok(r)
}

/// Check every file against the manifest and return the sources.
pub fn verify(r: &Request) -> Result<Vec<(PathBuf, String)>, String> {
    if total_hash(&r.files) != r.sha256 || !r.sha256.starts_with(&r.code) {
        return Err("the manifest does not match its own hash".into());
    }
    let mut out = Vec::new();
    for (n, h) in &r.files {
        let p = r.dir.join("src").join(n);
        let text = std::fs::read_to_string(&p).map_err(|e| format!("{n}: {e}"))?;
        if sha256::hex(text.as_bytes()) != *h {
            return Err(format!("{n} does not match its SHA-256"));
        }
        out.push((PathBuf::from(n), text));
    }
    Ok(out)
}

/// `rootplc deploy`: write a request for a checked and tested project, only
/// when it compiles and every test passes.
pub fn make_request(
    dir: &Path,
    tests: &TestReport,
    program: Option<&str>,
    libraries: &[String],
) -> Result<Request, String> {
    if !tests.check.ok() {
        return Err("the project does not compile; nothing was deployed".into());
    }
    let failed = tests.outcomes.iter().filter(|o| !o.passed()).count();
    if failed > 0 {
        return Err(format!("{failed} test(s) fail; nothing was deployed"));
    }
    let passed = tests.outcomes.len();
    let tmp = dir.join("pending").join(".incoming");
    let _ = std::fs::remove_dir_all(&tmp);
    let r = write_bundle(&tmp, &tests.check, program, libraries, (passed, 0))?;
    let to = dir.join("pending").join(&r.code);
    let _ = std::fs::remove_dir_all(&to);
    std::fs::rename(&tmp, &to).map_err(|e| format!("{}: {e}", to.display()))?;
    audit(
        dir,
        "request",
        &r.code,
        &format!("program={} tests={passed} by={}", r.program, user_name()),
    );
    read_request(&to)
}

/// Requests in `DIR/<state>` (`pending`, `approved`), sorted by code.
pub fn list(dir: &Path, state: &str) -> Vec<Request> {
    let mut v: Vec<Request> = std::fs::read_dir(dir.join(state))
        .map(|rd| {
            rd.flatten()
                .filter(|e| !e.file_name().to_string_lossy().starts_with('.'))
                .filter_map(|e| read_request(&e.path()).ok())
                .collect()
        })
        .unwrap_or_default();
    v.sort_by(|a, b| a.code.cmp(&b.code));
    v
}

/// Approve a pending request (the caller has confirmed that a person typed
/// the code at a terminal).
pub fn approve(dir: &Path, code: &str) -> Result<Request, String> {
    let from = dir.join("pending").join(code);
    read_request(&from).map_err(|_| format!("no pending request {code}"))?;
    let to = dir.join("approved").join(code);
    std::fs::create_dir_all(dir.join("approved")).map_err(|e| e.to_string())?;
    let _ = std::fs::remove_dir_all(&to);
    std::fs::rename(&from, &to).map_err(|e| e.to_string())?;
    audit(dir, "approve", code, &format!("by={}", user_name()));
    read_request(&to)
}

/// `rootplc approve --rollback`: the replaced program becomes a new request.
pub fn rollback_request(dir: &Path) -> Result<Request, String> {
    let prev = read_request(&dir.join("previous"))
        .map_err(|_| "there is no replaced program to roll back to".to_string())?;
    verify(&prev)?;
    let to = dir.join("pending").join(&prev.code);
    let _ = std::fs::remove_dir_all(&to);
    copy_dir(&prev.dir, &to).map_err(|e| e.to_string())?;
    audit(
        dir,
        "request",
        &prev.code,
        &format!("rollback by={}", user_name()),
    );
    read_request(&to)
}

fn copy_dir(from: &Path, to: &Path) -> std::io::Result<()> {
    std::fs::create_dir_all(to.join("src"))?;
    std::fs::copy(from.join("manifest.txt"), to.join("manifest.txt"))?;
    for e in std::fs::read_dir(from.join("src"))?.flatten() {
        std::fs::copy(e.path(), to.join("src").join(e.file_name()))?;
    }
    Ok(())
}

/// Record the program the runtime starts with as `DIR/current`, so a later
/// deploy can be rolled back to it.
pub fn record_current(
    dir: &Path,
    check: &CheckReport,
    program: Option<&str>,
    libraries: &[String],
) -> Result<Request, String> {
    let _ = std::fs::remove_dir_all(dir.join("current"));
    let r = write_bundle(&dir.join("current"), check, program, libraries, (0, 0))?;
    audit(dir, "start", &r.code, &format!("program={}", r.program));
    Ok(r)
}

/// Watches `DIR/approved` for the runtime ([runtime.deploy]).
pub struct Watcher {
    dir: PathBuf,
    period_ns: i128,
    taken: Option<Request>,
}

impl Watcher {
    /// Watch `dir`; programs run with cycle period `period_ns`.
    pub fn new(dir: &Path, period_ns: i128) -> Watcher {
        Watcher {
            dir: dir.to_path_buf(),
            period_ns,
            taken: None,
        }
    }

    fn reject(&self, r: &Request, why: &str) {
        let to = self.dir.join("rejected").join(&r.code);
        let _ = std::fs::create_dir_all(self.dir.join("rejected"));
        let _ = std::fs::remove_dir_all(&to);
        let _ = std::fs::rename(&r.dir, &to);
        audit(&self.dir, "reject", &r.code, why);
    }

    fn load(&self, r: &Request) -> Result<VmProgram<'static>, String> {
        let sources = verify(r)?;
        let check = check_sources_with(sources, &r.libraries)?;
        if !check.ok() {
            return Err("the program does not compile".into());
        }
        // The VM borrows the compiled program for as long as it runs; a
        // deployed program lives until the runtime stops (one per deploy).
        let check: &'static CheckReport = Box::leak(Box::new(check));
        let name = (!r.program.is_empty()).then_some(r.program.as_str());
        VmProgram::new(check, name, self.period_ns)
    }
}

impl Updates<VmProgram<'static>> for Watcher {
    fn poll(&mut self) -> Option<VmProgram<'static>> {
        for r in list(&self.dir, "approved") {
            match self.load(&r) {
                Ok(p) => {
                    self.taken = Some(r);
                    return Some(p);
                }
                Err(e) => self.reject(&r, &e),
            }
        }
        None
    }

    fn outcome(&mut self, result: Result<Vec<String>, String>) {
        let Some(r) = self.taken.take() else { return };
        match result {
            Ok(carried) => {
                let (cur, prev) = (self.dir.join("current"), self.dir.join("previous"));
                let _ = std::fs::remove_dir_all(&prev);
                let _ = std::fs::rename(&cur, &prev);
                let _ = std::fs::rename(&r.dir, &cur);
                audit(
                    &self.dir,
                    "swap",
                    &r.code,
                    &format!("retain carried: {}", carried.join(",")),
                );
            }
            Err(e) => self.reject(&r, &e),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rootplc_runtime::{Config, NoIo, Runtime, State, SystemClock};
    use std::sync::atomic::AtomicBool;

    fn tested(src: &str) -> TestReport {
        let check = crate::check_sources(vec![(PathBuf::from("counter.st"), src.to_string())]);
        crate::test_report(check, None)
    }

    const V1: &str = "PROGRAM Counter\nVAR RETAIN total : UDINT; END_VAR\ntotal := total + 1;\nEND_PROGRAM\n\
        TEST counts\nVAR c : Counter; END_VAR\nc(); ASSERT_EQ(UDINT#1, c.total);\nEND_TEST\n";
    const V2: &str = "PROGRAM Counter\nVAR RETAIN total : UDINT; END_VAR\nVAR step : UDINT := 100; END_VAR\n\
        total := total + step;\nEND_PROGRAM\n\
        TEST counts\nVAR c : Counter; END_VAR\nc(); ASSERT_EQ(UDINT#100, c.total);\nEND_TEST\n";

    #[test]
    fn utc_time_is_formatted() {
        let t = utc_now();
        assert_eq!(t.len(), 20);
        assert!(t.ends_with('Z') && t.starts_with("20"));
    }

    #[test]
    fn request_approve_swap_and_rollback() {
        let dir = std::env::temp_dir().join(format!("rootplc-deploy-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).expect("dir");

        // a failing test blocks the request
        let bad = tested(&V2.replace("UDINT#100", "UDINT#7"));
        assert!(make_request(&dir, &bad, None, &[]).is_err());

        let v1 = tested(V1);
        record_current(&dir, &v1.check, None, &[]).expect("current");
        let req = make_request(&dir, &tested(V2), None, &[]).expect("request");
        assert_eq!(list(&dir, "pending").len(), 1);
        assert_eq!(req.code.len(), 8);
        approve(&dir, &req.code).expect("approve");

        // tampering is caught before the swap
        let mut cfg = Config::with_period_ms(200);
        cfg.cycles = Some(10);
        let check: &'static CheckReport = Box::leak(Box::new(v1.check.clone()));
        let p = VmProgram::new(check, None, 200_000_000).expect("v1");
        let mut rt = Runtime::new(p, NoIo, SystemClock::default(), cfg).expect("rt");
        let mut w = Watcher::new(&dir, 200_000_000);
        let rep = rt.run_with(&AtomicBool::new(false), &mut w);
        assert_eq!(rep.state, State::Stopped);
        // v1 counted 1 per cycle for ~5 cycles (1 s), then v2 added 100 per cycle
        let total: u64 = rep
            .vars
            .iter()
            .find(|v| v.name == "total")
            .and_then(|v| v.value.parse().ok())
            .expect("total");
        assert!(total > 100 && total % 100 != 0, "total = {total}");
        let log = std::fs::read_to_string(dir.join("audit.log")).expect("log");
        for ev in ["\tstart\t", "\trequest\t", "\tapprove\t", "\tswap\t"] {
            assert!(log.contains(ev), "{ev} missing in {log}");
        }
        assert!(log.contains("retain carried: total"));
        assert_eq!(
            read_request(&dir.join("current")).expect("cur").code,
            req.code
        );

        // rollback makes the replaced program a new pending request
        let rb = rollback_request(&dir).expect("rollback");
        assert_eq!(list(&dir, "pending")[0].code, rb.code);

        // a request whose source was changed after approval is rejected
        approve(&dir, &rb.code).expect("approve rollback");
        let src = dir.join("approved").join(&rb.code).join("src");
        let f = std::fs::read_dir(&src)
            .expect("src")
            .flatten()
            .next()
            .expect("file")
            .path();
        std::fs::write(&f, "PROGRAM Counter\nEND_PROGRAM\n").expect("tamper");
        assert!(w.poll().is_none());
        let log = std::fs::read_to_string(dir.join("audit.log")).expect("log");
        assert!(log.contains("\treject\t") && log.contains("does not match its SHA-256"));
        let _ = std::fs::remove_dir_all(&dir);
    }
}
