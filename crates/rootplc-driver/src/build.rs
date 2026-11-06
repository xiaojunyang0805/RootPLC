//! `rootplc build --target c` (spec/18-codegen-c.md).

use rootplc_diag::json_string;
use rootplc_sema::ir::PouKind;

use crate::CheckReport;

/// Where the C back end stopped ([build.c.subset]).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Unsupported {
    /// File, 1-based line and column.
    pub file: String,
    /// Line.
    pub line: usize,
    /// Column.
    pub column: usize,
    /// The construct.
    pub construct: String,
}

/// Result of [`build_c`].
#[derive(Debug, Clone)]
pub struct BuildReport {
    /// Compilation result.
    pub check: CheckReport,
    /// The PROGRAM translated.
    pub program: String,
    /// The C file, when the program is supported.
    pub code: Option<String>,
    /// The first unsupported construct.
    pub unsupported: Option<Unsupported>,
}

impl BuildReport {
    /// Compiled and translated.
    pub fn ok(&self) -> bool {
        self.check.ok() && self.code.is_some()
    }
}

/// Translate PROGRAM `program` (or the only one) of a checked project to C.
pub fn build_c(check: CheckReport, program: Option<&str>) -> Result<BuildReport, String> {
    let Some(prog) = &check.program else {
        return Ok(BuildReport {
            check,
            program: String::new(),
            code: None,
            unsupported: None,
        });
    };
    let programs: Vec<usize> = (0..prog.defs.len())
        .filter(|&i| matches!(prog.pou(i), Some(p) if p.kind == PouKind::Program))
        .collect();
    let def = match program {
        Some(name) => prog
            .find(name)
            .filter(|i| programs.contains(i))
            .ok_or_else(|| format!("no PROGRAM named '{name}'"))?,
        None => match programs.as_slice() {
            [one] => *one,
            [] => return Err("the project has no PROGRAM".into()),
            _ => return Err("the project has several programs; choose one with --program".into()),
        },
    };
    let name = prog.defs[def].name.clone();
    let (code, unsupported) = match rootplc_codegen_c::generate(prog, def) {
        Ok(c) => (Some(c), None),
        Err(u) => {
            let (file, line, column) = crate::json::location(&check, u.file, u.offset);
            (
                None,
                Some(Unsupported {
                    file,
                    line,
                    column,
                    construct: u.construct,
                }),
            )
        }
    };
    Ok(BuildReport {
        check,
        program: name,
        code,
        unsupported,
    })
}

/// JSON report ([build.c.command]).
pub fn to_json(r: &BuildReport, out: &str) -> String {
    let unsupported = r.unsupported.as_ref().map_or("null".to_string(), |u| {
        format!(
            "{{\"file\":{},\"line\":{},\"column\":{},\"construct\":{}}}",
            json_string(&u.file),
            u.line,
            u.column,
            json_string(&u.construct)
        )
    });
    format!(
        "{{\"command\":\"build\",\"ok\":{},\"target\":\"c\",\"program\":{},\"out\":{},\"diagnostics\":{},\"unsupported\":{unsupported}}}",
        r.ok(),
        json_string(&r.program),
        json_string(out),
        crate::json::diagnostics(&r.check)
    )
}
