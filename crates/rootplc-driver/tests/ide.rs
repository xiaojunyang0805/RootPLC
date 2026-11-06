//! Editor features ([lsp.symbols], [lsp.diagnostics], [lsp.definition],
//! [lsp.hover]) on the conformance case `lsp/err_lsp_project.st`.

use std::path::{Path, PathBuf};

use rootplc_driver::ide::{SymKind, definition, hover, project_diagnostics, symbols};

fn case() -> (PathBuf, String) {
    let p = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../conformance/cases/lsp/err_lsp_project.st");
    let text = std::fs::read_to_string(&p).expect("case");
    (p, text)
}

fn line_of(text: &str, needle: &str) -> usize {
    text.lines().position(|l| l.contains(needle)).expect(needle)
}

#[test]
fn outline_of_the_project() {
    let (_, text) = case();
    let s = symbols(&text);
    let top: Vec<(&str, SymKind)> = s.iter().map(|x| (x.name.as_str(), x.kind)).collect();
    assert_eq!(
        top,
        [
            ("Cell", SymKind::Module),
            ("ST_Pos", SymKind::Type),
            ("FB_Axis", SymKind::Class),
            ("PRG_Main", SymKind::Module)
        ]
    );
    let cell: Vec<&str> = s[0].children.iter().map(|c| c.name.as_str()).collect();
    assert_eq!(cell, ["gSpeed"]);
    let fb: Vec<(&str, SymKind)> = s[2]
        .children
        .iter()
        .map(|c| (c.name.as_str(), c.kind))
        .collect();
    assert_eq!(
        fb,
        [
            ("target", SymKind::Variable),
            ("pos", SymKind::Variable),
            ("Home", SymKind::Method)
        ]
    );
}

#[test]
fn diagnostics_definition_and_hover() {
    let (p, text) = case();
    let files = vec![(p.clone(), text.clone())];
    let diags = project_diagnostics(files.clone(), &[]).expect("check");
    let d = &diags[0].1;
    assert_eq!(d.len(), 1);
    assert_eq!(
        (d[0].code.as_str(), d[0].line),
        ("RP0103", line_of(&text, "small := gSpeed"))
    );
    // `axis` in the body -> PRG_Main's declaration
    let body = line_of(&text, "axis.Home();");
    let loc = definition(&files, &p, body, 1).expect("axis");
    assert_eq!(loc.range.line, line_of(&text, "axis : FB_Axis"));
    // `Home` -> the method
    let loc = definition(&files, &p, body, 7).expect("Home");
    assert_eq!(loc.range.line, line_of(&text, "METHOD Home"));
    // `FB_Axis` in a declaration -> the block
    let decl = line_of(&text, "axis : FB_Axis");
    let loc = definition(&files, &p, decl, 13).expect("FB_Axis");
    assert_eq!(loc.range.line, line_of(&text, "FUNCTION_BLOCK FB_Axis"));
    // hover on the error explains RP0103; on a name shows the declaration
    let h = hover(&files, d, &p, d[0].line, d[0].col).expect("hover");
    assert!(h.starts_with("**RP0103**"), "{h}");
    let h = hover(&files, d, &p, decl, 5).expect("hover");
    assert!(h.contains("axis : FB_Axis"), "{h}");
}
