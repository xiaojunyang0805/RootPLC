//! Generated documentation: the diagnostics reference
//! (`docs/diagnostics/README.md`) and `docs/llms-full.txt`, the whole
//! agent-facing documentation in one file. Both come from the assets
//! compiled into this crate, so they always match the toolchain. The
//! conformance suite fails when the checked-in files are stale; set
//! `ROOTPLC_UPDATE_DOCS=1` and run it to regenerate them.

use crate::explain;

/// `docs/diagnostics/README.md`: every code with its rule text.
pub fn diagnostics_md() -> String {
    let all: Vec<explain::Explanation> = explain::codes()
        .iter()
        .filter_map(|c| explain::explain(c))
        .collect();
    let mut out = String::from(
        "# Diagnostics\n\n\
         *Generated from `spec/diagnostics.toml` and the spec chapters; do not edit.*\n\n\
         Every diagnostic has a stable code. `rootplc explain <code>` prints the same text.\n\
         Codes RP00xx are lexical, RP01xx types, RP02xx names and structure, RP03xx syntax.\n\n\
         | Code | Severity | Summary |\n|---|---|---|\n",
    );
    for e in &all {
        out.push_str(&format!(
            "| [{c}](#{l}) | {s} | {m} |\n",
            c = e.code,
            l = e.code.to_lowercase(),
            s = e.severity,
            m = e.summary.replace('|', "\\|")
        ));
    }
    for e in &all {
        out.push_str(&format!(
            "\n## {}\n\n{}: {}\n\nRule `{}` in `{}`:\n\n{}\n",
            e.code, e.severity, e.summary, e.rule, e.file, e.text
        ));
    }
    out
}

/// `docs/llms-full.txt`: guide, CLI, examples, diagnostics and the spec.
pub fn llms_full(cli_md: &str) -> String {
    let mut out = String::from(
        "# RootPLC: full documentation for language models\n\n\
         > Open, agent-first IEC 61131-3 toolchain. CLI `rootplc`, MCP server `rootplc mcp`. Apache-2.0.\n\
         > Generated from the toolchain's compiled-in assets; it matches this version exactly.\n\n",
    );
    let section = |out: &mut String, title: &str, body: &str| {
        out.push_str(&format!("\n\n======== {title} ========\n\n"));
        out.push_str(body.trim());
        out.push('\n');
    };
    section(&mut out, "Agent guide (AGENTS.md)", crate::init::AGENTS_MD);
    section(&mut out, "Command line", cli_md);
    let mut ex = String::new();
    for e in crate::examples::all() {
        ex.push_str(&format!("--- example: {} ---\n{}\n", e.id, e.source));
    }
    section(&mut out, "Verified examples", &ex);
    section(&mut out, "Diagnostics", &diagnostics_md());
    for (path, text) in explain::SPEC {
        section(&mut out, &format!("Specification: {path}"), text);
    }
    out
}

#[cfg(test)]
mod tests {
    #[test]
    fn every_code_has_a_section() {
        let md = super::diagnostics_md();
        for c in crate::explain::codes() {
            assert!(md.contains(&format!("\n## {c}\n")), "{c}");
        }
        let full = super::llms_full("CLI");
        assert!(full.contains("example: edge-detect") && full.contains("RP0103"));
    }
}
