//! `rootplc init`: create a project that checks and tests clean from the start.

use std::path::{Path, PathBuf};

const AGENTS_MD: &str = include_str!("../assets/AGENTS.md");

const MAIN_ST: &str = "(* Created by rootplc init. Replace it with your program. *)
PROGRAM PRG_Main
VAR_INPUT
    start, stop : BOOL;
END_VAR
VAR_OUTPUT
    running : BOOL;
END_VAR
running := (start OR running) AND NOT stop;
END_PROGRAM
";

const TEST_ST: &str = "(* Every program change needs a passing test. Run: rootplc test . *)
TEST start_latches_and_stop_resets
VAR
    uut : PRG_Main;
END_VAR
uut(start := TRUE);
uut(start := FALSE);
ASSERT_TRUE(uut.running);
uut(stop := TRUE);
ASSERT_FALSE(uut.running);
END_TEST
";

fn manifest(name: &str) -> String {
    format!(
        "[project]\nname = \"{name}\"\nversion = \"0.1.0\"\nspec = \"0\"\n\n[build]\ntarget = \"vm\"\n\n\
         [[task]]\nname = \"Main\"\ninterval = \"T#10ms\"\nprograms = [\"PRG_Main\"]\n"
    )
}

/// Create `rootplc.toml`, `src/main.st`, `tests/main_test.st` and `AGENTS.md`
/// in `dir`. Refuses to overwrite any existing file. Returns the created paths.
pub fn init(dir: &Path, name: Option<&str>) -> Result<Vec<PathBuf>, String> {
    let name = name.map(str::to_string).unwrap_or_else(|| {
        let base = std::fs::canonicalize(dir)
            .ok()
            .and_then(|p| p.file_name().map(|n| n.to_string_lossy().into_owned()))
            .unwrap_or_else(|| "plc-project".into());
        base.chars()
            .map(|c| {
                if c.is_ascii_alphanumeric() || c == '-' || c == '_' {
                    c
                } else {
                    '-'
                }
            })
            .collect()
    });
    let files = [
        (dir.join("rootplc.toml"), manifest(&name)),
        (dir.join("src").join("main.st"), MAIN_ST.to_string()),
        (dir.join("tests").join("main_test.st"), TEST_ST.to_string()),
        (dir.join("AGENTS.md"), AGENTS_MD.to_string()),
    ];
    let existing: Vec<String> = files
        .iter()
        .filter(|(p, _)| p.exists())
        .map(|(p, _)| p.display().to_string())
        .collect();
    if !existing.is_empty() {
        return Err(format!(
            "not overwriting existing files: {}",
            existing.join(", ")
        ));
    }
    let mut created = Vec::new();
    for (path, text) in files {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent).map_err(|e| format!("{}: {e}", parent.display()))?;
        }
        std::fs::write(&path, text).map_err(|e| format!("{}: {e}", path.display()))?;
        created.push(path);
    }
    Ok(created)
}

#[cfg(test)]
mod tests {
    #[test]
    fn new_project_checks_and_tests_clean() {
        let dir = std::env::temp_dir().join(format!("rootplc-init-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).expect("temp dir");
        let created = super::init(&dir, Some("demo")).expect("init");
        assert_eq!(created.len(), 4);
        let report = crate::test(std::slice::from_ref(&dir), None).expect("test");
        assert!(
            report.ok(),
            "{:?}",
            report
                .check
                .files
                .iter()
                .map(|f| &f.diagnostics)
                .collect::<Vec<_>>()
        );
        assert_eq!(report.outcomes.len(), 1);
        assert!(super::init(&dir, None).is_err(), "must not overwrite");
        let _ = std::fs::remove_dir_all(&dir);
    }
}
