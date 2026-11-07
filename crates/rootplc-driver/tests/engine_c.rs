//! The C engine ([runtime.engine]) and the C runtime ([build.c.shim])
//! against the VM engine: the same program under the same virtual clock and
//! inputs gives the same variables and the same image. Skipped without a C
//! compiler for shared libraries (engine) or a POSIX C compiler (shim).

use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::AtomicBool;

use rootplc_driver::runtime::{Engine, RunOptions, run_runtime};
use rootplc_runtime::{Clock, Config, Image, IoDriver, Report, State};

fn program() -> String {
    let p = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../conformance/cases/runtime/ok_engine_c_io.st");
    std::fs::read_to_string(p).expect("case")
}

/// Time moves only when the runtime sleeps: one period per cycle.
struct Virtual(u64);

impl Clock for Virtual {
    fn now_ns(&mut self) -> u64 {
        self.0
    }
    fn sleep_until(&mut self, ns: u64) {
        self.0 = self.0.max(ns);
    }
}

/// Inputs: start pressed, level 21.
struct Inputs;

impl IoDriver for Inputs {
    fn read_inputs(&mut self, image: &mut Image) {
        image.input[0] = 1;
        image.input[2..4].copy_from_slice(&21i16.to_le_bytes());
    }
    fn write_outputs(&mut self, _: &Image) {}
}

fn check() -> rootplc_driver::CheckReport {
    let c = rootplc_driver::check_sources_with(vec![(PathBuf::from("io.st"), program())], &[])
        .expect("check");
    assert!(c.ok());
    c
}

fn run(engine: Engine, cycles: u64) -> Result<Report, String> {
    run_retain(engine, cycles, None)
}

fn run_retain(engine: Engine, cycles: u64, retain: Option<&Path>) -> Result<Report, String> {
    let mut cfg = Config::with_period_ms(10);
    cfg.cycles = Some(cycles);
    cfg.retain = retain.map(Path::to_path_buf);
    let mut opts = RunOptions::new(cfg);
    opts.engine = engine;
    run_runtime(&check(), opts, Inputs, Virtual(0), &AtomicBool::new(false))
}

fn value(r: &Report, name: &str) -> String {
    r.vars
        .iter()
        .find(|v| v.name == name)
        .map(|v| v.value.clone())
        .unwrap_or_default()
}

#[test]
fn c_engine_matches_the_vm_engine() {
    if rootplc_driver::native::find_compiler().is_none() {
        eprintln!("engine_c: no C compiler for shared libraries; skipped");
        return;
    }
    let vm = run(Engine::Vm, 25).expect("vm");
    let c = match run(Engine::C, 25) {
        Ok(r) => r,
        Err(e) => panic!("C engine: {e}"),
    };
    assert_eq!(vm.state, State::Stopped);
    assert_eq!(c.state, State::Stopped);
    assert_eq!(c.stats.cycles, 25);
    for name in [
        "start", "level", "lamp", "speed", "hold", "count", "tally", "starts",
    ] {
        assert_eq!(value(&c, name), value(&vm, name), "{name}");
    }
    assert!(c.notes.iter().any(|n| n.contains("C engine")));
}

#[test]
fn c_engine_names_what_it_cannot_run() {
    if rootplc_driver::native::find_compiler().is_none() {
        return;
    }
    let src = "TYPE U_Word : UNION w : WORD; b : BYTE; END_UNION; END_TYPE\nPROGRAM P\nVAR u : U_Word; n : INT; END_VAR\nn := n + 1;\nEND_PROGRAM\n";
    let c = rootplc_driver::check_sources_with(vec![(PathBuf::from("p.st"), src.into())], &[])
        .expect("check");
    if !c.ok() {
        return;
    }
    let mut opts = RunOptions::new(Config::with_period_ms(10));
    opts.engine = Engine::C;
    let e =
        run_runtime(&c, opts, Inputs, Virtual(0), &AtomicBool::new(false)).expect_err("refuses");
    assert!(e.contains("C engine cannot run this program"), "{e}");
}

/// A POSIX C compiler for the shim: gcc/cc here, or gcc in WSL on Windows.
fn posix_cc() -> Option<(bool, String)> {
    let sh = Command::new("sh")
        .args(["-c", "true"])
        .output()
        .is_ok_and(|o| o.status.success());
    if !cfg!(windows) && sh {
        for cc in ["cc", "gcc", "clang"] {
            if Command::new(cc)
                .arg("--version")
                .output()
                .is_ok_and(|o| o.status.success())
            {
                return Some((false, cc.into()));
            }
        }
    }
    if cfg!(windows)
        && Command::new("wsl.exe")
            .args(["gcc", "--version"])
            .output()
            .is_ok_and(|o| o.status.success())
    {
        return Some((true, "gcc".into()));
    }
    None
}

fn wsl_path(p: &Path) -> String {
    let s = p.display().to_string().replace('\\', "/");
    match s.split_once(":/") {
        Some((d, rest)) if d.len() == 1 => format!("/mnt/{}/{rest}", d.to_ascii_lowercase()),
        _ => s,
    }
}

#[test]
fn c_runtime_shim_matches_the_vm_engine() {
    let Some((wsl, cc)) = posix_cc() else {
        eprintln!("engine_c: no POSIX C compiler for runtime-c; skipped");
        return;
    };
    let r = rootplc_driver::build::build_c(check(), None).expect("build");
    let dir = std::env::temp_dir().join(format!("rootplc-shim-{}", std::process::id()));
    std::fs::create_dir_all(&dir).expect("dir");
    std::fs::write(dir.join("rootplc_program.c"), r.code.expect("code")).expect("write");
    // a RETAIN file written by the Rust runtime (VM engine), for the shim to read
    let rust_retain = dir.join("rust.retain");
    let first = run_retain(Engine::Vm, 25, Some(&rust_retain)).expect("vm");
    assert_eq!(value(&first, "starts"), "5");
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).join("../..");
    let p = |x: &Path| {
        if wsl {
            wsl_path(x)
        } else {
            x.display().to_string()
        }
    };
    let src = |f: &str| p(&repo.join(f));
    let script = format!(
        "{cc} -std=c99 -O2 -I'{inc}' '{prog}' '{rt}' '{svc}' '{mb}' '{port}' -lm -o '{exe}' > '{log}' 2>&1 &&          {cc} -std=c99 -I'{inc}' '{mb}' '{tm}' -o '{tmexe}' >> '{log}' 2>&1 && '{tmexe}' > '{tmout}' 2>&1;          '{exe}' --virtual --cycles 25 --set I0=1 --set I2=21 --retain '{shim_retain}' > '{out}' 2>&1;          '{exe}' --virtual --cycles 5 --set I0=1 --set I2=21 --retain '{rust_retain}' --json > '{json}' 2>&1",
        inc = src("runtime-c/include"),
        prog = p(&dir.join("rootplc_program.c")),
        rt = src("runtime-c/src/rootplc_rt.c"),
        svc = src("runtime-c/src/rootplc_services.c"),
        mb = src("runtime-c/src/rootplc_modbus.c"),
        port = src("runtime-c/ports/posix/main.c"),
        tm = src("runtime-c/test/test_modbus.c"),
        exe = p(&dir.join("plc")),
        tmexe = p(&dir.join("test_modbus")),
        log = p(&dir.join("cc.txt")),
        out = p(&dir.join("out.txt")),
        tmout = p(&dir.join("tm.txt")),
        json = p(&dir.join("json.txt")),
        shim_retain = p(&dir.join("shim.retain")),
        rust_retain = p(&rust_retain),
    );
    let status = if wsl {
        Command::new("wsl.exe").args(["sh", "-c", &script]).status()
    } else {
        Command::new("sh").args(["-c", &script]).status()
    };
    assert!(status.is_ok());
    let read = |f: &str| std::fs::read_to_string(dir.join(f)).unwrap_or_default();
    let (out, log) = (read("out.txt"), read("cc.txt"));
    assert!(
        out.contains("cycles=25"),
        "shim did not run:
{log}
{out}"
    );
    // the Modbus handler answers as the Rust runtime's
    assert!(
        read("tm.txt").contains("test_modbus: ok"),
        "{}",
        read("tm.txt")
    );
    let shim = |name: &str| {
        out.lines()
            .find_map(|l| l.strip_prefix(&format!("{name}=")))
            .unwrap_or_default()
            .to_string()
    };
    let vm = run(Engine::Vm, 25).expect("vm");
    for name in [
        "start", "level", "lamp", "speed", "count", "tally", "starts", "hold",
    ] {
        assert_eq!(shim(name), value(&vm, name), "{name}");
    }
    assert_eq!(shim("state"), "stopped");
    // output image: lamp bit 1 of byte 0, speed in bytes 2..4, tally in byte 4
    let img = shim("out");
    let speed = 42u16.to_le_bytes();
    assert_eq!(&img[4..8], format!("{:02X}{:02X}", speed[0], speed[1]));
    assert_eq!(&img[8..10], format!("{:02X}", 25u8));
    // RETAIN: the shim's file is the Rust runtime's format, both ways
    let shim_retain = read("shim.retain");
    assert_eq!(
        shim_retain,
        "starts	UDINT	5
"
    );
    let again = run_retain(Engine::Vm, 25, Some(&dir.join("shim.retain"))).expect("vm");
    assert!(
        again.notes.iter().any(|n| n.contains("restored 1 RETAIN")),
        "{:?}",
        again.notes
    );
    assert_eq!(value(&again, "starts"), "10");
    let json = read("json.txt");
    assert!(
        json.starts_with("{\"command\":\"runtime\",\"state\":\"stopped\""),
        "{json}"
    );
    assert!(json.contains("restored 1 RETAIN variable(s)"), "{json}");
    assert!(
        json.contains("{\"name\":\"starts\",\"type\":\"UDINT\",\"at\":null,\"value\":\"6\"}"),
        "{json}"
    );
    let _ = std::fs::remove_dir_all(&dir);
}
