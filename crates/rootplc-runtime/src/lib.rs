//! Reference runtime on PREEMPT_RT Linux: scheduler, program loading, force/trace, online change, signed deploy, runtime agent API.
//!
//! Roadmap phase: 3. See `ARCHITECTURE.md`. Version 0 (spec/14-runtime.md)
//! is demo grade: one program in a cyclic task ([runtime.cycle]), the
//! process image bound to located variables ([runtime.image]), a watchdog
//! with safe outputs ([runtime.watchdog]), retained variables
//! ([runtime.retain]) and a status report ([runtime.status]). It sees the
//! program only through [`rootplc_abi::Program`]; time and I/O come in
//! through [`Clock`] and [`IoDriver`], so the same loop runs on a board, on a
//! development machine and in deterministic tests.

use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use rootplc_abi::{Address, Area, Kind, MAX_AREA, Program, Scalar, bindable, load, store_n, width};

pub mod modbus;
/// The C engine ([runtime.engine]): FFI to a compiled program; with `ffi`
/// the only places where `unsafe` may appear in this crate.
#[allow(unsafe_code)]
pub mod native;

/// FFI and hardware access. With `native`, the only places where `unsafe`
/// may appear in this crate; every block needs a `// SAFETY:` comment and a Kani proof or justification.
#[allow(unsafe_code)]
pub mod ffi {
    use std::sync::atomic::{AtomicBool, Ordering};

    static STOP: AtomicBool = AtomicBool::new(false);

    /// Install a handler for Ctrl-C and SIGTERM (Unix) or the console
    /// control events (Windows) that sets the returned flag, so the runtime
    /// stops at a cycle boundary and saves RETAIN variables
    /// ([runtime.retain]). Storing to an atomic is async-signal-safe.
    pub fn stop_on_interrupt() -> &'static AtomicBool {
        os::install();
        &STOP
    }

    #[cfg(unix)]
    mod os {
        use super::{Ordering, STOP};

        unsafe extern "C" {
            fn signal(sig: i32, handler: usize) -> usize;
        }

        extern "C" fn on_signal(_: i32) {
            STOP.store(true, Ordering::SeqCst);
        }

        pub fn install() {
            // SAFETY: `signal` is the C library's; the handler only stores
            // to a static atomic, which is async-signal-safe, and has the C
            // ABI `void(int)` that `signal` expects. 2 = SIGINT, 15 = SIGTERM.
            unsafe {
                signal(2, on_signal as extern "C" fn(i32) as usize);
                signal(15, on_signal as extern "C" fn(i32) as usize);
            }
        }
    }

    #[cfg(windows)]
    mod os {
        use super::{Ordering, STOP};

        type Handler = unsafe extern "system" fn(u32) -> i32;

        #[link(name = "kernel32")]
        unsafe extern "system" {
            fn SetConsoleCtrlHandler(handler: Option<Handler>, add: i32) -> i32;
        }

        unsafe extern "system" fn on_ctrl(_: u32) -> i32 {
            STOP.store(true, Ordering::SeqCst);
            1
        }

        pub fn install() {
            // SAFETY: documented Win32 API; the handler matches
            // PHANDLER_ROUTINE (BOOL WINAPI f(DWORD)) and only stores to a
            // static atomic; returning TRUE marks the event handled.
            unsafe {
                SetConsoleCtrlHandler(Some(on_ctrl), 1);
            }
        }
    }

    #[cfg(not(any(unix, windows)))]
    mod os {
        pub fn install() {}
    }
}

/// The process image: inputs, outputs and memory ([runtime.image]).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Image {
    /// `%I` area.
    pub input: Vec<u8>,
    /// `%Q` area.
    pub output: Vec<u8>,
    /// `%M` area.
    pub memory: Vec<u8>,
}

impl Image {
    fn area_mut(&mut self, a: Area) -> &mut Vec<u8> {
        match a {
            Area::Input => &mut self.input,
            Area::Output => &mut self.output,
            Area::Memory => &mut self.memory,
        }
    }

    fn area(&self, a: Area) -> &[u8] {
        match a {
            Area::Input => &self.input,
            Area::Output => &self.output,
            Area::Memory => &self.memory,
        }
    }
}

/// Exchanges the image with the hardware once per cycle.
pub trait IoDriver {
    /// Fill the input image before the program runs.
    fn read_inputs(&mut self, image: &mut Image);
    /// Write the output image after the program ran.
    fn write_outputs(&mut self, image: &Image);
}

/// An I/O driver that leaves the image to other users (an HMI, a Modbus
/// server, a test): inputs are whatever they set.
#[derive(Debug, Default, Clone, Copy)]
pub struct NoIo;

impl IoDriver for NoIo {
    fn read_inputs(&mut self, _: &mut Image) {}
    fn write_outputs(&mut self, _: &Image) {}
}

/// A source of time.
pub trait Clock {
    /// Nanoseconds since an arbitrary start.
    fn now_ns(&mut self) -> u64;
    /// Wait until `ns` (no wait if it has passed).
    fn sleep_until(&mut self, ns: u64);
}

/// The machine's monotonic clock.
#[derive(Debug, Clone, Copy)]
pub struct SystemClock {
    start: Instant,
}

impl Default for SystemClock {
    fn default() -> Self {
        SystemClock {
            start: Instant::now(),
        }
    }
}

impl Clock for SystemClock {
    fn now_ns(&mut self) -> u64 {
        self.start.elapsed().as_nanos() as u64
    }
    fn sleep_until(&mut self, ns: u64) {
        let now = self.now_ns();
        if ns > now {
            std::thread::sleep(Duration::from_nanos(ns - now));
        }
    }
}

/// Settings of a run.
#[derive(Debug, Clone)]
pub struct Config {
    /// Cycle period.
    pub period_ns: u64,
    /// Watchdog time; a cycle running longer is a fault.
    pub watchdog_ns: u64,
    /// Stop after this many cycles.
    pub cycles: Option<u64>,
    /// File for RETAIN variables ([runtime.retain]).
    pub retain: Option<PathBuf>,
    /// File for the live status report ([runtime.status]).
    pub status: Option<PathBuf>,
}

impl Config {
    /// Defaults for a period: watchdog ten periods, no files.
    pub fn with_period_ms(ms: u64) -> Config {
        let period_ns = ms.max(1) * 1_000_000;
        Config {
            period_ns,
            watchdog_ns: period_ns * 10,
            cycles: None,
            retain: None,
            status: None,
        }
    }
}

/// State of the runtime.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum State {
    /// Cycling.
    Running,
    /// Stopped on request or after the requested cycles.
    Stopped,
    /// Stopped by a fault; outputs are safe ([runtime.watchdog]).
    Fault(String),
}

/// Cycle statistics ([runtime.cycle]).
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Stats {
    /// Completed cycles.
    pub cycles: u64,
    /// Shortest execution time.
    pub exec_min_ns: u64,
    /// Longest execution time.
    pub exec_max_ns: u64,
    /// Sum of execution times (for the average).
    pub exec_sum_ns: u128,
    /// Largest start delay against the planned start.
    pub jitter_max_ns: u64,
    /// Cycles that took longer than the period.
    pub overruns: u64,
}

impl Stats {
    /// Average execution time.
    pub fn exec_avg_ns(&self) -> u64 {
        if self.cycles == 0 {
            0
        } else {
            (self.exec_sum_ns / u128::from(self.cycles)) as u64
        }
    }
}

/// One variable in the status report.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct VarValue {
    /// Name.
    pub name: String,
    /// Type name.
    pub type_name: String,
    /// Direct address, if located.
    pub at: Option<String>,
    /// Value as IEC literal text.
    pub value: String,
}

/// The status report ([runtime.status]).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Report {
    /// State.
    pub state: State,
    /// Period.
    pub period_ns: u64,
    /// Cycle statistics.
    pub stats: Stats,
    /// Notes from start-up (retain file restored, variables not retained).
    pub notes: Vec<String>,
    /// Variables and their values.
    pub vars: Vec<VarValue>,
}

/// Where a source of new programs is asked, once a second at a cycle
/// boundary ([runtime.deploy]).
pub trait Updates<P> {
    /// An approved program to run from the next cycle, if any.
    fn poll(&mut self) -> Option<P>;
    /// The outcome of the last program returned by `poll`: the RETAIN
    /// variables carried over, or why it was rejected.
    fn outcome(&mut self, result: Result<Vec<String>, String>);
}

/// No updates: the program never changes.
pub struct NoUpdates;

impl<P> Updates<P> for NoUpdates {
    fn poll(&mut self) -> Option<P> {
        None
    }
    fn outcome(&mut self, _: Result<Vec<String>, String>) {}
}

/// Bindings of one program.
struct Bound {
    bindings: Vec<Binding>,
    retained: Vec<usize>,
    notes: Vec<String>,
}

/// Bind the located variables of `program` (growing the image as needed)
/// and list its elementary RETAIN variables ([runtime.image.type]).
fn bind<P: Program>(program: &P, image: &mut Image) -> Result<Bound, String> {
    let mut bindings = Vec::new();
    let mut problems = Vec::new();
    for (i, v) in program.vars().iter().enumerate() {
        let Some(at) = &v.at else { continue };
        match Address::parse(at) {
            Ok(addr)
                if bindable(v.kind, addr.size) && addr.byte + width(addr, v.kind) <= MAX_AREA =>
            {
                let area = image.area_mut(addr.area);
                let end = addr.byte + width(addr, v.kind);
                if area.len() < end {
                    area.resize(end, 0);
                }
                bindings.push(Binding {
                    var: i,
                    addr,
                    kind: v.kind,
                });
            }
            Ok(addr) if !bindable(v.kind, addr.size) && v.kind == Kind::Other => {
                problems.push(format!(
                    "{} AT {addr}: type {} is not elementary; version 0 cannot bind it",
                    v.name, v.type_name
                ))
            }
            Ok(addr) if !bindable(v.kind, addr.size) => problems.push(format!(
                "{} AT {addr}: type {} does not fit a bit address",
                v.name, v.type_name
            )),
            Ok(addr) => problems.push(format!(
                "{} AT {addr}: type {} runs past the end of the image",
                v.name, v.type_name
            )),
            Err(e) => problems.push(format!("{}: {e}", v.name)),
        }
    }
    if !problems.is_empty() {
        return Err(format!("cannot run: {}", problems.join("; ")));
    }
    let mut notes = Vec::new();
    let mut retained = Vec::new();
    for (i, v) in program.vars().iter().enumerate().filter(|(_, v)| v.retain) {
        if v.kind == Kind::Other {
            notes.push(format!(
                "{} ({}) is RETAIN but not elementary; it keeps its initial value",
                v.name, v.type_name
            ));
        } else {
            retained.push(i);
        }
    }
    Ok(Bound {
        bindings,
        retained,
        notes,
    })
}

/// A located variable bound to its place.
#[derive(Debug, Clone, Copy)]
struct Binding {
    var: usize,
    addr: Address,
    kind: Kind,
}

/// Runtime v0: one program, one cyclic task.
pub struct Runtime<P: Program, D: IoDriver, C: Clock> {
    program: P,
    io: D,
    clock: C,
    config: Config,
    /// The image, shared with other users (HMI, Modbus server, tests).
    pub image: Arc<Mutex<Image>>,
    bindings: Vec<Binding>,
    /// Value of each binding read at cycle start (`None` for outputs).
    at_start: Vec<Option<Scalar>>,
    retained: Vec<usize>,
    notes: Vec<String>,
    state: State,
    stats: Stats,
    last_save_ns: u64,
}

impl<P: Program, D: IoDriver, C: Clock> Runtime<P, D, C> {
    /// Bind the located variables and restore RETAIN variables. Fails, naming
    /// the variables, when an address is not runnable ([runtime.image.type]).
    pub fn new(program: P, io: D, clock: C, config: Config) -> Result<Self, String> {
        let mut image = Image::default();
        let b = bind(&program, &mut image)?;
        let mut rt = Runtime {
            program,
            io,
            clock,
            config,
            image: Arc::new(Mutex::new(image)),
            bindings: b.bindings,
            at_start: Vec::new(),
            retained: b.retained,
            notes: b.notes,
            state: State::Running,
            stats: Stats::default(),
            last_save_ns: 0,
        };
        rt.restore();
        Ok(rt)
    }

    /// [runtime.deploy]: replace the program at a cycle boundary. Binds the
    /// new program, carries over RETAIN variables with the same name and
    /// type, and keeps the image. On an error the running program stays.
    /// Returns the names of the variables carried over.
    pub fn replace(&mut self, program: P) -> Result<Vec<String>, String> {
        let image = Arc::clone(&self.image);
        let mut img = image.lock().unwrap_or_else(|e| e.into_inner());
        let mut grown = img.clone();
        let b = bind(&program, &mut grown)?;
        let mut new = program;
        let mut carried = Vec::new();
        for &old in &self.retained {
            let o = &self.program.vars()[old];
            let Some(v) = self.program.read(old) else {
                continue;
            };
            let hit = b.retained.iter().copied().find(|&i| {
                let n = &new.vars()[i];
                n.name.eq_ignore_ascii_case(&o.name)
                    && n.type_name.eq_ignore_ascii_case(&o.type_name)
            });
            if let Some(i) = hit {
                if new.write(i, v) {
                    carried.push(o.name.clone());
                }
            }
        }
        *img = grown;
        self.program = new;
        self.bindings = b.bindings;
        self.retained = b.retained;
        self.at_start.clear();
        self.notes.extend(b.notes);
        Ok(carried)
    }

    /// Add a note to the report (for example where a server listens).
    pub fn note(&mut self, text: String) {
        self.notes.push(text);
    }

    /// The program (for reading variables after a run).
    pub fn program(&self) -> &P {
        &self.program
    }

    /// Current state.
    pub fn state(&self) -> &State {
        &self.state
    }

    /// Run until `stop` is set, the requested cycles are done, or a fault.
    pub fn run(&mut self, stop: &AtomicBool) -> Report {
        self.run_with(stop, &mut NoUpdates)
    }

    /// [`Runtime::run`], asking `updates` for an approved program once a
    /// second at a cycle boundary ([runtime.deploy]).
    pub fn run_with(&mut self, stop: &AtomicBool, updates: &mut dyn Updates<P>) -> Report {
        let mut planned = self.clock.now_ns();
        let mut last_start: Option<u64> = None;
        while self.state == State::Running {
            if stop.load(Ordering::Relaxed)
                || self.config.cycles.is_some_and(|n| self.stats.cycles >= n)
            {
                self.state = State::Stopped;
                break;
            }
            self.clock.sleep_until(planned);
            let start = self.clock.now_ns();
            let elapsed = last_start.map_or(0, |l| start.saturating_sub(l));
            last_start = Some(start);
            let jitter = start.saturating_sub(planned);
            self.inputs();
            let result = self.program.cycle(elapsed);
            let exec = self.clock.now_ns().saturating_sub(start);
            let fault = match result {
                Err(e) => Some(e),
                Ok(()) if exec > self.config.watchdog_ns => Some(format!(
                    "watchdog: the cycle took {} us, the watchdog is {} us",
                    exec / 1000,
                    self.config.watchdog_ns / 1000
                )),
                Ok(()) => None,
            };
            if let Some(reason) = fault {
                self.safe_outputs();
                self.state = State::Fault(reason);
                break;
            }
            self.outputs();
            let s = &mut self.stats;
            s.exec_min_ns = if s.cycles == 0 {
                exec
            } else {
                s.exec_min_ns.min(exec)
            };
            s.exec_max_ns = s.exec_max_ns.max(exec);
            s.exec_sum_ns += u128::from(exec);
            s.jitter_max_ns = s.jitter_max_ns.max(jitter);
            s.cycles += 1;
            planned += self.config.period_ns;
            let now = self.clock.now_ns();
            if exec > self.config.period_ns || planned < now {
                s.overruns += u64::from(exec > self.config.period_ns);
                planned = planned.max(now);
            }
            if now.saturating_sub(self.last_save_ns) >= 1_000_000_000 {
                self.last_save_ns = now;
                if let Some(p) = updates.poll() {
                    let r = self.replace(p);
                    updates.outcome(r);
                }
                self.save();
                self.write_status();
            }
        }
        self.save();
        self.write_status();
        self.report()
    }

    /// Copy the input and memory images into the located variables, under
    /// the image lock (other users such as the Modbus server write between
    /// cycles).
    fn inputs(&mut self) {
        let image = Arc::clone(&self.image);
        let mut img = image.lock().unwrap_or_else(|e| e.into_inner());
        self.io.read_inputs(&mut img);
        self.at_start.clear();
        for b in &self.bindings {
            let v =
                (b.addr.area != Area::Output).then(|| load(img.area(b.addr.area), b.addr, b.kind));
            if let Some(v) = v {
                self.program.write(b.var, v);
            }
            self.at_start.push(v);
        }
    }

    /// Copy the located outputs into the image, and memory variables the
    /// program changed (so a memory write by another user during the cycle
    /// is kept), then hand the outputs to the driver.
    fn outputs(&mut self) {
        let image = Arc::clone(&self.image);
        let mut img = image.lock().unwrap_or_else(|e| e.into_inner());
        for (k, b) in self.bindings.iter().enumerate() {
            let Some(v) = self.program.read(b.var) else {
                continue;
            };
            let changed = self.at_start.get(k).copied().flatten() != Some(v);
            if b.addr.area == Area::Output || (b.addr.area == Area::Memory && changed) {
                store_n(img.area_mut(b.addr.area), b.addr, v, width(b.addr, b.kind));
            }
        }
        self.io.write_outputs(&img);
    }

    /// [runtime.watchdog]: every output bit 0, written once more.
    fn safe_outputs(&mut self) {
        let image = Arc::clone(&self.image);
        let mut img = image.lock().unwrap_or_else(|e| e.into_inner());
        img.output.iter_mut().for_each(|b| *b = 0);
        self.io.write_outputs(&img);
    }

    /// [runtime.retain]: restore RETAIN variables from the file.
    fn restore(&mut self) {
        let Some(path) = self.config.retain.clone() else {
            return;
        };
        let Ok(text) = std::fs::read_to_string(&path) else {
            return;
        };
        let mut restored = 0;
        for line in text.lines() {
            let mut parts = line.splitn(3, '\t');
            let (Some(name), Some(ty), Some(val)) = (parts.next(), parts.next(), parts.next())
            else {
                continue;
            };
            let found = self.retained.iter().copied().find(|&i| {
                let v = &self.program.vars()[i];
                v.name.eq_ignore_ascii_case(name)
            });
            let Some(i) = found else {
                self.notes
                    .push(format!("retain file: {name} is no longer RETAIN; ignored"));
                continue;
            };
            let info = self.program.vars()[i].clone();
            if !info.type_name.eq_ignore_ascii_case(ty) {
                self.notes.push(format!(
                    "retain file: {name} changed type ({ty} -> {}); it keeps its initial value",
                    info.type_name
                ));
                continue;
            }
            match parse_scalar(info.kind, val) {
                Some(v) if self.program.write(i, v) => restored += 1,
                _ => self
                    .notes
                    .push(format!("retain file: {name} = {val} cannot be restored")),
            }
        }
        self.notes.push(format!(
            "restored {restored} RETAIN variable(s) from {}",
            path.display()
        ));
    }

    /// [runtime.retain]: save RETAIN variables (new file, then rename).
    fn save(&mut self) {
        let Some(path) = self.config.retain.clone() else {
            return;
        };
        let mut out = String::new();
        for &i in &self.retained {
            if let Some(v) = self.program.read(i) {
                let info = &self.program.vars()[i];
                out.push_str(&format!("{}\t{}\t{v}\n", info.name, info.type_name));
            }
        }
        let _ = write_atomic(&path, &out);
    }

    fn write_status(&mut self) {
        if let Some(path) = self.config.status.clone() {
            let _ = write_atomic(&path, &to_json(&self.report()));
        }
    }

    /// The status report now.
    pub fn report(&self) -> Report {
        let vars = self
            .program
            .vars()
            .iter()
            .enumerate()
            .map(|(i, v)| VarValue {
                name: v.name.clone(),
                type_name: v.type_name.clone(),
                at: v.at.clone(),
                value: self.program.text(i),
            })
            .collect();
        Report {
            state: self.state.clone(),
            period_ns: self.config.period_ns,
            stats: self.stats.clone(),
            notes: self.notes.clone(),
            vars,
        }
    }
}

fn parse_scalar(kind: Kind, text: &str) -> Option<Scalar> {
    let t = text.trim();
    match kind {
        Kind::Bool => match t.to_ascii_uppercase().as_str() {
            "TRUE" => Some(Scalar::Bool(true)),
            "FALSE" => Some(Scalar::Bool(false)),
            _ => None,
        },
        Kind::Int(_) => t.parse().ok().map(Scalar::Int),
        Kind::UInt(_) => t.parse().ok().map(Scalar::UInt),
        Kind::Real | Kind::LReal => t.parse().ok().map(Scalar::Real),
        Kind::Other => None,
    }
}

/// Write a file so that a power loss leaves the old or the new content.
pub fn write_atomic(path: &std::path::Path, text: &str) -> std::io::Result<()> {
    let tmp = path.with_extension("tmp");
    std::fs::write(&tmp, text)?;
    std::fs::rename(&tmp, path)
}

fn esc(s: &str) -> String {
    let mut o = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            '\n' => o.push_str("\\n"),
            c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)),
            c => o.push(c),
        }
    }
    o.push('"');
    o
}

/// The report as JSON ([runtime.status]).
pub fn to_json(r: &Report) -> String {
    let (state, fault) = match &r.state {
        State::Running => ("running", "null".to_string()),
        State::Stopped => ("stopped", "null".to_string()),
        State::Fault(f) => ("fault", esc(f)),
    };
    let s = &r.stats;
    let vars: Vec<String> = r
        .vars
        .iter()
        .map(|v| {
            format!(
                "{{\"name\":{},\"type\":{},\"at\":{},\"value\":{}}}",
                esc(&v.name),
                esc(&v.type_name),
                v.at.as_deref().map_or_else(|| "null".to_string(), esc),
                esc(&v.value)
            )
        })
        .collect();
    let notes: Vec<String> = r.notes.iter().map(|n| esc(n)).collect();
    format!(
        "{{\"command\":\"runtime\",\"state\":\"{state}\",\"fault\":{fault},\"period_us\":{},\"cycles\":{},\"exec_us\":{{\"min\":{},\"avg\":{},\"max\":{}}},\"jitter_max_us\":{},\"overruns\":{},\"notes\":[{}],\"variables\":[{}]}}",
        r.period_ns / 1000,
        s.cycles,
        s.exec_min_ns / 1000,
        s.exec_avg_ns() / 1000,
        s.exec_max_ns / 1000,
        s.jitter_max_ns / 1000,
        s.overruns,
        notes.join(","),
        vars.join(",")
    )
}

/// The report as text.
pub fn to_text(r: &Report) -> String {
    let s = &r.stats;
    let mut o = match &r.state {
        State::Fault(f) => format!("state: fault: {f}\n"),
        State::Running => "state: running\n".to_string(),
        State::Stopped => "state: stopped\n".to_string(),
    };
    o.push_str(&format!(
        "cycles: {} at {} ms; execution min/avg/max {}/{}/{} us; jitter max {} us; overruns {}\n",
        s.cycles,
        r.period_ns as f64 / 1e6,
        s.exec_min_ns / 1000,
        s.exec_avg_ns() / 1000,
        s.exec_max_ns / 1000,
        s.jitter_max_ns / 1000,
        s.overruns
    ));
    for n in &r.notes {
        o.push_str(&format!("note: {n}\n"));
    }
    for v in &r.vars {
        let at =
            v.at.as_deref()
                .map(|a| format!(" AT {a}"))
                .unwrap_or_default();
        o.push_str(&format!(
            "  {}{at} : {} = {}\n",
            v.name, v.type_name, v.value
        ));
    }
    o
}

#[cfg(test)]
mod tests {
    use super::*;
    use rootplc_abi::VarInfo;

    /// A clock that jumps to whatever time is asked for; each cycle costs
    /// `cost` ns of "execution".
    struct FakeClock {
        now: u64,
        cost: u64,
        in_cycle: bool,
    }
    impl Clock for FakeClock {
        fn now_ns(&mut self) -> u64 {
            if self.in_cycle {
                self.now += self.cost;
            }
            self.in_cycle = !self.in_cycle;
            self.now
        }
        fn sleep_until(&mut self, ns: u64) {
            self.now = self.now.max(ns);
            self.in_cycle = false;
        }
    }

    /// btn AT %IX0.0 -> lamp AT %QX0.0 := btn; count (RETAIN) counts cycles;
    /// level AT %IW2 copied to out AT %QW2; fails at cycle `fail_at`.
    struct Toy {
        vars: Vec<VarInfo>,
        vals: Vec<Scalar>,
        n: u64,
        fail_at: Option<u64>,
        elapsed: Vec<u64>,
    }
    fn info(name: &str, kind: Kind, ty: &str, at: Option<&str>, retain: bool) -> VarInfo {
        VarInfo {
            name: name.into(),
            kind,
            type_name: ty.into(),
            at: at.map(Into::into),
            retain,
        }
    }
    impl Toy {
        fn new(fail_at: Option<u64>) -> Toy {
            Toy {
                vars: vec![
                    info("btn", Kind::Bool, "BOOL", Some("%IX0.0"), false),
                    info("lamp", Kind::Bool, "BOOL", Some("%QX0.0"), false),
                    info("count", Kind::UInt(4), "UDINT", None, true),
                    info("level", Kind::Int(2), "INT", Some("%IW2"), false),
                    info("out", Kind::Int(2), "INT", Some("%QW2"), false),
                ],
                vals: vec![
                    Scalar::Bool(false),
                    Scalar::Bool(false),
                    Scalar::UInt(0),
                    Scalar::Int(0),
                    Scalar::Int(0),
                ],
                n: 0,
                fail_at,
                elapsed: Vec::new(),
            }
        }
    }
    impl Program for Toy {
        fn vars(&self) -> &[VarInfo] {
            &self.vars
        }
        fn read(&self, i: usize) -> Option<Scalar> {
            self.vals.get(i).copied()
        }
        fn text(&self, i: usize) -> String {
            self.vals[i].to_string()
        }
        fn write(&mut self, i: usize, v: Scalar) -> bool {
            self.vals[i] = v;
            true
        }
        fn cycle(&mut self, elapsed_ns: u64) -> Result<(), String> {
            self.elapsed.push(elapsed_ns);
            self.n += 1;
            if Some(self.n) == self.fail_at {
                return Err("division by zero".into());
            }
            self.vals[1] = self.vals[0];
            if let (Scalar::UInt(c), Scalar::Int(l)) = (self.vals[2], self.vals[3]) {
                self.vals[2] = Scalar::UInt(c + 1);
                self.vals[4] = Scalar::Int(l * 2);
            }
            Ok(())
        }
    }

    fn rt(toy: Toy, cost: u64, cfg: Config) -> Runtime<Toy, NoIo, FakeClock> {
        let clock = FakeClock {
            now: 0,
            cost,
            in_cycle: false,
        };
        Runtime::new(toy, NoIo, clock, cfg).expect("binds")
    }

    #[test]
    fn image_flows_through_the_program_each_cycle() {
        let mut cfg = Config::with_period_ms(10);
        cfg.cycles = Some(3);
        let mut r = rt(Toy::new(None), 1_000, cfg);
        {
            let mut img = r.image.lock().expect("image");
            img.input[0] = 1;
            img.input[2..4].copy_from_slice(&21i16.to_le_bytes());
        }
        let rep = r.run(&AtomicBool::new(false));
        assert_eq!(rep.state, State::Stopped);
        assert_eq!(rep.stats.cycles, 3);
        let img = r.image.lock().expect("image").clone();
        assert_eq!(img.output[0] & 1, 1);
        assert_eq!(i16::from_le_bytes([img.output[2], img.output[3]]), 42);
        // time advances by the period between cycle starts
        assert_eq!(r.program().elapsed, vec![0, 10_000_000, 10_000_000]);
        assert_eq!(rep.stats.overruns, 0);
        assert_eq!(rep.stats.exec_max_ns, 1_000);
    }

    #[test]
    fn a_fault_stops_with_safe_outputs() {
        let mut cfg = Config::with_period_ms(10);
        cfg.cycles = Some(10);
        let mut r = rt(Toy::new(Some(3)), 1_000, cfg);
        r.image.lock().expect("image").input[0] = 1;
        let rep = r.run(&AtomicBool::new(false));
        assert_eq!(rep.state, State::Fault("division by zero".into()));
        assert_eq!(rep.stats.cycles, 2);
        assert!(
            r.image
                .lock()
                .expect("image")
                .output
                .iter()
                .all(|&b| b == 0)
        );
        assert!(to_json(&rep).contains("\"state\":\"fault\""));
    }

    #[test]
    fn watchdog_and_overruns() {
        let mut cfg = Config::with_period_ms(10);
        cfg.cycles = Some(2);
        // 15 ms per cycle: overruns, but below the 100 ms watchdog
        let rep = rt(Toy::new(None), 15_000_000, cfg.clone()).run(&AtomicBool::new(false));
        assert_eq!(rep.state, State::Stopped);
        assert_eq!(rep.stats.overruns, 2);
        // 150 ms per cycle: the watchdog fires
        let rep = rt(Toy::new(None), 150_000_000, cfg).run(&AtomicBool::new(false));
        assert!(matches!(rep.state, State::Fault(ref f) if f.starts_with("watchdog")));
    }

    #[test]
    fn retain_survives_a_restart() {
        let dir = std::env::temp_dir().join(format!("rootplc-rt-{}", std::process::id()));
        std::fs::create_dir_all(&dir).expect("dir");
        let file = dir.join("retain.txt");
        let _ = std::fs::remove_file(&file);
        let mut cfg = Config::with_period_ms(10);
        cfg.cycles = Some(5);
        cfg.retain = Some(file.clone());
        let rep = rt(Toy::new(None), 1_000, cfg.clone()).run(&AtomicBool::new(false));
        assert!(rep.vars.iter().any(|v| v.name == "count" && v.value == "5"));
        let rep = rt(Toy::new(None), 1_000, cfg).run(&AtomicBool::new(false));
        assert!(
            rep.vars
                .iter()
                .any(|v| v.name == "count" && v.value == "10"),
            "{rep:?}"
        );
        assert!(rep.notes.iter().any(|n| n.starts_with("restored 1")));
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn unrunnable_addresses_are_refused() {
        let mut toy = Toy::new(None);
        toy.vars[3].at = Some("%IX0.1".into()); // INT on a bit
        toy.vars[4].at = Some("%Q*".into());
        let err = Runtime::new(
            toy,
            NoIo,
            SystemClock::default(),
            Config::with_period_ms(10),
        )
        .err()
        .expect("refused");
        assert!(
            err.contains("level AT %IX0.1") && err.contains("out:"),
            "{err}"
        );
    }

    struct OneSwap(Option<Toy>, Vec<Result<Vec<String>, String>>);
    impl Updates<Toy> for OneSwap {
        fn poll(&mut self) -> Option<Toy> {
            self.0.take()
        }
        fn outcome(&mut self, r: Result<Vec<String>, String>) {
            self.1.push(r);
        }
    }

    #[test]
    fn an_approved_program_replaces_the_running_one_keeping_retain() {
        let mut cfg = Config::with_period_ms(500);
        cfg.cycles = Some(6);
        let mut r = rt(Toy::new(None), 1_000, cfg);
        let mut next = Toy::new(None);
        next.vals[2] = Scalar::UInt(1000); // ignored: count comes from the old program
        let mut up = OneSwap(Some(next), Vec::new());
        let rep = r.run_with(&AtomicBool::new(false), &mut up);
        assert_eq!(up.1, vec![Ok(vec!["count".to_string()])]);
        // swapped after the 2nd cycle (1 s); 6 cycles counted across both programs
        assert!(
            rep.vars.iter().any(|v| v.name == "count" && v.value == "6"),
            "{rep:?}"
        );
        // a program that cannot bind is rejected and the old one keeps running
        let mut bad = Toy::new(None);
        bad.vars[3].at = Some("%IX0.1".into());
        assert!(r.replace(bad).is_err());
        assert_eq!(r.program().vars[3].at.as_deref(), Some("%IW2"));
    }
}
