//! Build a program into a shared library for the C engine
//! ([runtime.engine]): translate it with the C back end and compile it
//! with the host's C compiler.

use std::path::{Path, PathBuf};
use std::process::Command;

use crate::CheckReport;

/// A C compiler that can build shared libraries.
#[derive(Debug, Clone)]
pub enum Compiler {
    /// gcc, clang or cc (also MinGW on Windows).
    Gnu(String),
    /// MSVC through its vcvars script.
    Msvc(PathBuf),
}

fn runs(cmd: &str) -> bool {
    Command::new(cmd)
        .arg("--version")
        .output()
        .is_ok_and(|o| o.status.success())
}

/// The vcvars64.bat of an installed Visual Studio (Build Tools included).
fn vcvars() -> Option<PathBuf> {
    for root in [
        "C:\\Program Files\\Microsoft Visual Studio",
        "C:\\Program Files (x86)\\Microsoft Visual Studio",
    ] {
        let Ok(years) = std::fs::read_dir(root) else {
            continue;
        };
        let mut years: Vec<PathBuf> = years.filter_map(|e| e.ok().map(|e| e.path())).collect();
        years.sort();
        for y in years.iter().rev() {
            let Ok(eds) = std::fs::read_dir(y) else {
                continue;
            };
            for e in eds.filter_map(Result::ok) {
                let v = e.path().join("VC\\Auxiliary\\Build\\vcvars64.bat");
                if v.is_file() {
                    return Some(v);
                }
            }
        }
    }
    None
}

/// Find a compiler: `ROOTPLC_CC`, then cc, gcc, clang; on Windows also
/// MSVC.
pub fn find_compiler() -> Option<Compiler> {
    if let Ok(cc) = std::env::var("ROOTPLC_CC") {
        return Some(Compiler::Gnu(cc));
    }
    for cc in ["cc", "gcc", "clang"] {
        if runs(cc) {
            return Some(Compiler::Gnu(cc.into()));
        }
    }
    if cfg!(windows) {
        return vcvars().map(Compiler::Msvc);
    }
    None
}

/// Compile with MSVC: `cmd /c "call vcvars64.bat && cl ..."`; the line is
/// passed to cmd as it is (cmd does not read Rust's argument quoting).
#[cfg(windows)]
fn msvc(
    vcvars: &Path,
    src: &Path,
    lib: &Path,
    dir: &Path,
) -> std::io::Result<std::process::Output> {
    use std::os::windows::process::CommandExt;
    let line = format!(
        "/c \"call \"{}\" >nul 2>nul && cl /nologo /O2 /LD /DROOTPLC_SHARED \"{}\" /Fe:\"{}\" /Fo:\"{}\\\\\"\"",
        vcvars.display(),
        src.display(),
        lib.display(),
        dir.display()
    );
    Command::new("cmd").raw_arg(line).current_dir(dir).output()
}

#[cfg(not(windows))]
fn msvc(_: &Path, _: &Path, _: &Path, _: &Path) -> std::io::Result<std::process::Output> {
    Err(std::io::Error::other("MSVC is only used on Windows"))
}

/// Translate PROGRAM `program` to C in `dir` and compile it to a shared
/// library; returns the library's path.
pub fn build_shared(
    check: &CheckReport,
    program: Option<&str>,
    dir: &Path,
) -> Result<PathBuf, String> {
    let r = crate::build::build_c(check.clone(), program)?;
    let Some(code) = r.code else {
        return Err(match r.unsupported {
            Some(u) => format!(
                "the C engine cannot run this program: {}:{}:{}: {} (not supported by the C back end yet)",
                u.file, u.line, u.column, u.construct
            ),
            None => "the project does not compile".into(),
        });
    };
    std::fs::create_dir_all(dir).map_err(|e| format!("{}: {e}", dir.display()))?;
    let src = dir.join("rootplc_program.c");
    std::fs::write(&src, code).map_err(|e| format!("{}: {e}", src.display()))?;
    let lib = dir.join(if cfg!(windows) {
        "rootplc_program.dll"
    } else if cfg!(target_os = "macos") {
        "librootplc_program.dylib"
    } else {
        "librootplc_program.so"
    });
    let compiler = find_compiler().ok_or(
        "the C engine needs a C compiler (cc, gcc or clang, or MSVC on Windows; or set ROOTPLC_CC)",
    )?;
    let out = match &compiler {
        Compiler::Gnu(cc) => {
            let mut cmd = Command::new(cc);
            cmd.args(["-std=c99", "-O2", "-shared", "-DROOTPLC_SHARED"]);
            if !cfg!(windows) {
                cmd.arg("-fPIC");
            }
            cmd.arg(&src).arg("-o").arg(&lib);
            if !cfg!(windows) {
                cmd.arg("-lm");
            }
            cmd.output()
        }
        Compiler::Msvc(vcvars) => msvc(vcvars, &src, &lib, dir),
    }
    .map_err(|e| format!("cannot run the C compiler: {e}"))?;
    if !out.status.success() || !lib.is_file() {
        let text = String::from_utf8_lossy(&out.stdout).to_string()
            + &String::from_utf8_lossy(&out.stderr);
        let first: Vec<&str> = text.lines().take(12).collect();
        return Err(format!("the C compiler failed:\n{}", first.join("\n")));
    }
    Ok(lib)
}
