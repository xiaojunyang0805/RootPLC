//! The C engine ([runtime.engine]): a program translated by
//! `rootplc build --target c` and compiled to a shared library, loaded at
//! run time and driven through its ABI variable table ([build.c.abi]).
//! FFI: one of the two places in this crate where `unsafe` may appear
//! (ARCHITECTURE.md rule 5). The library's state is touched only through
//! this object, from the thread that runs the program.

use std::ffi::{CStr, c_char, c_void};
use std::path::Path;

use rootplc_abi::{ABI_VERSION, Kind, Program, Scalar, VarInfo};

/// `rootplc_var` of the generated C file.
#[repr(C)]
struct RawVar {
    name: *const c_char,
    kind: u8,
    bytes: u8,
    type_name: *const c_char,
    at: *const c_char,
    retain: u8,
    ptr: *mut c_void,
}

#[cfg(unix)]
mod sys {
    use std::ffi::{c_char, c_int, c_void};
    #[cfg_attr(target_os = "linux", link(name = "dl"))]
    unsafe extern "C" {
        pub fn dlopen(filename: *const c_char, flag: c_int) -> *mut c_void;
        pub fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;
        pub fn dlerror() -> *const c_char;
    }
    pub const RTLD_NOW: c_int = 2;
}

#[cfg(windows)]
mod sys {
    use std::ffi::{c_char, c_void};
    #[link(name = "kernel32")]
    unsafe extern "system" {
        pub fn LoadLibraryW(name: *const u16) -> *mut c_void;
        pub fn GetProcAddress(module: *mut c_void, name: *const c_char) -> *mut c_void;
    }
}

/// Open a shared library; the handle is never closed (the program runs
/// until the process ends).
fn open(path: &Path) -> Result<*mut c_void, String> {
    #[cfg(unix)]
    {
        use std::os::unix::ffi::OsStrExt;
        let mut bytes = path.as_os_str().as_bytes().to_vec();
        bytes.push(0);
        // SAFETY: a NUL-terminated path; dlerror returns a C string or NULL
        let h = unsafe { sys::dlopen(bytes.as_ptr().cast(), sys::RTLD_NOW) };
        if h.is_null() {
            let e = unsafe { sys::dlerror() };
            let msg = if e.is_null() {
                "unknown error".to_string()
            } else {
                unsafe { CStr::from_ptr(e) }.to_string_lossy().to_string()
            };
            return Err(format!("{}: {msg}", path.display()));
        }
        Ok(h)
    }
    #[cfg(windows)]
    {
        use std::os::windows::ffi::OsStrExt;
        let wide: Vec<u16> = path.as_os_str().encode_wide().chain(Some(0)).collect();
        // SAFETY: a NUL-terminated wide path
        let h = unsafe { sys::LoadLibraryW(wide.as_ptr()) };
        if h.is_null() {
            return Err(format!("{}: cannot load the library", path.display()));
        }
        Ok(h)
    }
}

fn symbol(h: *mut c_void, name: &str) -> Result<*mut c_void, String> {
    let c = format!("{name}\0");
    #[cfg(unix)]
    // SAFETY: a valid handle and a NUL-terminated name
    let p = unsafe { sys::dlsym(h, c.as_ptr().cast()) };
    #[cfg(windows)]
    // SAFETY: a valid handle and a NUL-terminated name
    let p = unsafe { sys::GetProcAddress(h, c.as_ptr().cast()) };
    if p.is_null() {
        return Err(format!(
            "the library has no symbol {name} (not built by rootplc build --target c?)"
        ));
    }
    Ok(p)
}

fn text(p: *const c_char) -> Option<String> {
    if p.is_null() {
        None
    } else {
        // SAFETY: the generated table holds NUL-terminated string literals
        Some(unsafe { CStr::from_ptr(p) }.to_string_lossy().to_string())
    }
}

/// A program compiled to native code.
pub struct NativeProgram {
    vars: Vec<VarInfo>,
    ptrs: Vec<*mut c_void>,
    step: unsafe extern "C" fn(i64) -> i32,
}

// SAFETY: the library's globals are reached only through this object, and
// the runtime drives it from one thread at a time.
unsafe impl Send for NativeProgram {}

fn fault_name(code: i32) -> &'static str {
    match code {
        1 => "DIV_BY_ZERO",
        2 => "INDEX",
        3 => "RANGE",
        4 => "NULL_REF",
        _ => "UNKNOWN",
    }
}

impl NativeProgram {
    /// Load a library built from `rootplc build --target c` and initialise
    /// its program (FB_init included).
    pub fn load(path: &Path) -> Result<NativeProgram, String> {
        let h = open(path)?;
        let version = symbol(h, "rootplc_abi_version")?;
        let init = symbol(h, "rootplc_init")?;
        let step = symbol(h, "rootplc_step")?;
        let table = symbol(h, "rootplc_vars")?;
        let count = symbol(h, "rootplc_nvars")?;
        // SAFETY: the symbols have the types the generated file declares
        // ([build.c.abi]); the table has rootplc_nvars entries
        unsafe {
            let version: unsafe extern "C" fn() -> u32 = std::mem::transmute(version);
            if version() != ABI_VERSION {
                return Err(format!("{}: built for another ABI version", path.display()));
            }
            let init: unsafe extern "C" fn() = std::mem::transmute(init);
            let step: unsafe extern "C" fn(i64) -> i32 = std::mem::transmute(step);
            let n = *(count as *const i32);
            let rows = std::slice::from_raw_parts(table as *const RawVar, n.max(0) as usize);
            let mut vars = Vec::with_capacity(rows.len());
            let mut ptrs = Vec::with_capacity(rows.len());
            for r in rows {
                let kind = match (r.kind, r.bytes) {
                    (1, _) => Kind::Bool,
                    (2, b) => Kind::Int(b),
                    (3, b) => Kind::UInt(b),
                    (4, _) => Kind::Real,
                    (5, _) => Kind::LReal,
                    _ => Kind::Other,
                };
                vars.push(VarInfo {
                    name: text(r.name).unwrap_or_default(),
                    kind,
                    type_name: text(r.type_name).unwrap_or_default(),
                    at: text(r.at),
                    retain: r.retain != 0,
                });
                ptrs.push(r.ptr);
            }
            init();
            Ok(NativeProgram { vars, ptrs, step })
        }
    }
}

impl Program for NativeProgram {
    fn vars(&self) -> &[VarInfo] {
        &self.vars
    }

    fn read(&self, i: usize) -> Option<Scalar> {
        let p = *self.ptrs.get(i)?;
        let kind = self.vars.get(i)?.kind;
        // SAFETY: p points at the variable's storage of the given kind
        unsafe {
            Some(match kind {
                Kind::Bool => Scalar::Bool(*(p as *const u8) != 0),
                Kind::Int(1) => Scalar::Int(i64::from(*(p as *const i8))),
                Kind::Int(2) => Scalar::Int(i64::from(*(p as *const i16))),
                Kind::Int(4) => Scalar::Int(i64::from(*(p as *const i32))),
                Kind::Int(_) => Scalar::Int(*(p as *const i64)),
                Kind::UInt(1) => Scalar::UInt(u64::from(*(p as *const u8))),
                Kind::UInt(2) => Scalar::UInt(u64::from(*(p as *const u16))),
                Kind::UInt(4) => Scalar::UInt(u64::from(*(p as *const u32))),
                Kind::UInt(_) => Scalar::UInt(*(p as *const u64)),
                Kind::Real => Scalar::Real(f64::from(*(p as *const f32))),
                Kind::LReal => Scalar::Real(*(p as *const f64)),
                Kind::Other => return None,
            })
        }
    }

    fn text(&self, i: usize) -> String {
        match (self.read(i), self.vars.get(i).map(|v| v.kind)) {
            // a REAL as its single-precision digits, as the VM shows it
            (Some(Scalar::Real(x)), Some(Kind::Real)) => format!("{:?}", x as f32),
            (Some(v), _) => v.to_string(),
            (None, _) => String::from("(not elementary)"),
        }
    }

    fn write(&mut self, i: usize, v: Scalar) -> bool {
        let (Some(&p), Some(info)) = (self.ptrs.get(i), self.vars.get(i)) else {
            return false;
        };
        let int = match v {
            Scalar::Bool(b) => i64::from(b),
            Scalar::Int(n) => n,
            Scalar::UInt(n) => n as i64,
            Scalar::Real(x) => x as i64,
        };
        let real = match v {
            Scalar::Real(x) => x,
            Scalar::Bool(b) => f64::from(u8::from(b)),
            Scalar::Int(n) => n as f64,
            Scalar::UInt(n) => n as f64,
        };
        // SAFETY: p points at the variable's storage of the given kind
        unsafe {
            match info.kind {
                Kind::Bool => *(p as *mut u8) = u8::from(int != 0),
                Kind::Int(1) | Kind::UInt(1) => *(p as *mut u8) = int as u8,
                Kind::Int(2) | Kind::UInt(2) => *(p as *mut u16) = int as u16,
                Kind::Int(4) | Kind::UInt(4) => *(p as *mut u32) = int as u32,
                Kind::Int(_) | Kind::UInt(_) => *(p as *mut u64) = int as u64,
                Kind::Real => *(p as *mut f32) = real as f32,
                Kind::LReal => *(p as *mut f64) = real,
                Kind::Other => return false,
            }
        }
        true
    }

    fn cycle(&mut self, elapsed_ns: u64) -> Result<(), String> {
        // SAFETY: the library's step function, called from one thread
        let code = unsafe { (self.step)(elapsed_ns as i64) };
        if code == 0 {
            Ok(())
        } else {
            Err(format!("{} (C engine)", fault_name(code)))
        }
    }
}
