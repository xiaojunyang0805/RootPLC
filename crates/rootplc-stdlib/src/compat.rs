//! Compatibility libraries: vendor interfaces (names and signatures) written
//! in ST, so that vendor code checks and runs unchanged.
//!
//! A library is dormant until activated out of band (a CLI option, an MCP
//! argument, a project setting, or the corpus tool reading a TwinCAT
//! `.plcproj`); RootPLC never infers a library from source text. Its
//! declarations join the project under their exact vendor names. Functions
//! listed as `declare_only` are type-checked but not run: a call is warning
//! RP0120, and executing one stops with the fault UNSUPPORTED.
//!
//! Each library is a directory `libs/<Name>/` with a `library.toml` manifest
//! and a `<version>/` folder of `.st` files, written clean-room from the public
//! references the manifest lists. See spec/08-stdlib.md [stdlib.compat].

/// One compatibility library.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Library {
    /// Identity, e.g. `Tc2_System` (matched case-insensitively).
    pub name: String,
    /// Whose interface the library mirrors (nominative only).
    pub vendor: String,
    /// Version of the bundled files.
    pub version: String,
    /// One line.
    pub description: String,
    /// Functions that are declared but not implemented by RootPLC.
    pub declare_only: Vec<String>,
    /// Public sources the declarations were written from.
    pub references: Vec<String>,
    /// Compiler operators the library enables, e.g. `SIZEOF`.
    pub intrinsics: Vec<String>,
    /// Libraries it builds on; activated with it.
    pub requires: Vec<String>,
    /// ST files: (name, source).
    pub files: Vec<(&'static str, &'static str)>,
}

/// (manifest, files) of every bundled library.
const BUNDLED: &[(&str, &[(&str, &str)])] = &[
    (
        include_str!("../libs/Tc2_System/library.toml"),
        &[(
            "Tc2_System.st",
            include_str!("../libs/Tc2_System/1.0.0/Tc2_System.st"),
        )],
    ),
    (
        include_str!("../libs/Tc2_Standard/library.toml"),
        &[(
            "Tc2_Standard.st",
            include_str!("../libs/Tc2_Standard/1.0.0/Tc2_Standard.st"),
        )],
    ),
    (
        include_str!("../libs/Tc2_Utilities/library.toml"),
        &[(
            "Tc2_Utilities.st",
            include_str!("../libs/Tc2_Utilities/1.0.0/Tc2_Utilities.st"),
        )],
    ),
    (
        include_str!("../libs/TwinCAT_BuiltIns/library.toml"),
        &[(
            "TwinCAT_BuiltIns.st",
            include_str!("../libs/TwinCAT_BuiltIns/1.0.0/TwinCAT_BuiltIns.st"),
        )],
    ),
];

/// A string value or a list of strings from the small TOML subset the
/// manifests use (`key = "value"`, `key = ["a", "b"]` over several lines).
fn manifest(text: &str) -> Vec<(String, Vec<String>)> {
    let mut out: Vec<(String, Vec<String>)> = Vec::new();
    let mut open: Option<(String, Vec<String>)> = None;
    let strings = |s: &str| -> Vec<String> {
        s.split('"')
            .enumerate()
            .filter(|(i, _)| i % 2 == 1)
            .map(|(_, v)| v.to_string())
            .collect()
    };
    for line in text.lines() {
        let line = line.trim();
        if line.starts_with('#') || line.is_empty() {
            continue;
        }
        if let Some((key, mut vals)) = open.take() {
            vals.extend(strings(line));
            if line.contains(']') {
                out.push((key, vals));
            } else {
                open = Some((key, vals));
            }
            continue;
        }
        let Some((k, v)) = line.split_once('=') else {
            continue;
        };
        let (k, v) = (k.trim().to_string(), v.trim());
        if v.starts_with('[') && !v.contains(']') {
            open = Some((k, strings(v)));
        } else {
            out.push((k, strings(v)));
        }
    }
    out
}

fn parse(text: &str, files: &[(&'static str, &'static str)]) -> Library {
    let m = manifest(text);
    let one = |k: &str| {
        m.iter()
            .find(|(key, _)| key == k)
            .and_then(|(_, v)| v.first().cloned())
            .unwrap_or_default()
    };
    let many = |k: &str| {
        m.iter()
            .find(|(key, _)| key == k)
            .map(|(_, v)| v.clone())
            .unwrap_or_default()
    };
    Library {
        name: one("name"),
        vendor: one("vendor"),
        version: one("version"),
        description: one("description"),
        declare_only: many("declare_only"),
        references: many("references"),
        intrinsics: many("intrinsics"),
        requires: many("requires"),
        files: files.to_vec(),
    }
}

/// Every bundled library, in name order.
pub fn libraries() -> Vec<Library> {
    let mut v: Vec<Library> = BUNDLED.iter().map(|(t, f)| parse(t, f)).collect();
    v.sort_by(|a, b| a.name.cmp(&b.name));
    v
}

/// The named libraries and everything they require, without duplicates, in
/// dependency order. Unknown names are returned in the error.
pub fn resolve(names: &[String]) -> Result<Vec<Library>, String> {
    let mut out: Vec<Library> = Vec::new();
    fn add(name: &str, out: &mut Vec<Library>, depth: usize) -> Result<(), String> {
        let lib = find(name).ok_or_else(|| name.to_string())?;
        if out.iter().any(|l| l.name == lib.name) || depth > 16 {
            return Ok(());
        }
        for r in &lib.requires {
            add(r, out, depth + 1)?;
        }
        if !out.iter().any(|l| l.name == lib.name) {
            out.push(lib);
        }
        Ok(())
    }
    for n in names
        .iter()
        .flat_map(|n| n.split(','))
        .map(str::trim)
        .filter(|n| !n.is_empty())
    {
        add(n, &mut out, 0)?;
    }
    Ok(out)
}

/// A bundled library by name (case-insensitive).
pub fn find(name: &str) -> Option<Library> {
    libraries()
        .into_iter()
        .find(|l| l.name.eq_ignore_ascii_case(name.trim()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn manifests_are_complete() {
        let libs = libraries();
        assert!(libs.len() >= 2);
        for l in &libs {
            assert!(!l.name.is_empty() && !l.vendor.is_empty(), "{l:?}");
            assert!(!l.version.is_empty() && !l.description.is_empty(), "{l:?}");
            assert!(!l.references.is_empty(), "{}: no public references", l.name);
            assert!(!l.files.is_empty(), "{}: no files", l.name);
            for d in &l.declare_only {
                assert!(
                    l.files
                        .iter()
                        .any(|(_, s)| s.contains(&format!("FUNCTION {d} "))
                            || s.lines().any(|x| x.trim() == format!("FUNCTION_BLOCK {d}"))),
                    "{}: declare_only {d} is not declared",
                    l.name
                );
            }
        }
        let tc = find("tc2_system").expect("Tc2_System");
        assert_eq!(
            tc.declare_only,
            [
                "ADSLOGSTR",
                "ADSLOGDINT",
                "ADSLOGLREAL",
                "GETCPUCOUNTER",
                "MEMCPY",
                "MEMMOVE",
                "MEMSET",
                "MEMCMP"
            ]
        );
        assert_eq!(tc.references.len(), 18);
        assert!(find("nope").is_none());
        let r = resolve(&["Tc2_Utilities".into()]).expect("resolve");
        let names: Vec<&str> = r.iter().map(|l| l.name.as_str()).collect();
        assert_eq!(names, ["TwinCAT_BuiltIns", "Tc2_System", "Tc2_Utilities"]);
        assert!(resolve(&["Tc9_Nope".into()]).is_err());
        assert_eq!(
            find("TwinCAT_BuiltIns").expect("builtins").intrinsics,
            ["SIZEOF", "XSIZEOF", "PVOID"]
        );
    }
}
