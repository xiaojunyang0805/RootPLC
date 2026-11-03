//! `rootplc init --agent <host>`: write the configuration that connects an
//! agent host to the RootPLC MCP server (`rootplc mcp`) and points it at the
//! project's AGENTS.md. Existing files are never overwritten: a file that
//! already mentions rootplc is left alone, and any other existing file is
//! reported with the snippet to merge by hand.

use std::path::{Path, PathBuf};

/// Supported agent hosts.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Host {
    /// Claude Code: `.mcp.json` and `CLAUDE.md`.
    Claude,
    /// Gemini CLI: `.gemini/settings.json`.
    Gemini,
    /// Qwen Code: `.qwen/settings.json`.
    Qwen,
    /// Cursor: `.cursor/mcp.json` (reads AGENTS.md itself).
    Cursor,
    /// OpenAI Codex CLI: `.codex/config.toml` (reads AGENTS.md itself).
    Codex,
}

impl Host {
    /// Every host, in help order.
    pub const ALL: &'static [Host] = &[
        Host::Claude,
        Host::Gemini,
        Host::Qwen,
        Host::Cursor,
        Host::Codex,
    ];

    /// Name used on the command line.
    pub fn name(self) -> &'static str {
        match self {
            Host::Claude => "claude",
            Host::Gemini => "gemini",
            Host::Qwen => "qwen",
            Host::Cursor => "cursor",
            Host::Codex => "codex",
        }
    }

    /// Parse `claude`, `gemini`, ... or `all` (comma lists allowed).
    pub fn parse_list(text: &str) -> Result<Vec<Host>, String> {
        let mut out = Vec::new();
        for w in text.split(',').map(str::trim).filter(|w| !w.is_empty()) {
            if w.eq_ignore_ascii_case("all") {
                return Ok(Host::ALL.to_vec());
            }
            let h = Host::ALL
                .iter()
                .copied()
                .find(|h| h.name().eq_ignore_ascii_case(w))
                .ok_or_else(|| {
                    let names: Vec<_> = Host::ALL.iter().map(|h| h.name()).collect();
                    format!("unknown agent '{w}'; use {} or all", names.join(", "))
                })?;
            if !out.contains(&h) {
                out.push(h);
            }
        }
        if out.is_empty() {
            return Err("give an agent host, e.g. --agent claude".into());
        }
        Ok(out)
    }

    /// Files this host needs: (path relative to the project, content).
    pub fn files(self) -> Vec<(&'static str, &'static str)> {
        const MCP_JSON: &str = "{\n  \"mcpServers\": {\n    \"rootplc\": { \"command\": \"rootplc\", \"args\": [\"mcp\"] }\n  }\n}\n";
        const GEMINI_STYLE: &str = "{\n  \"mcpServers\": {\n    \"rootplc\": { \"command\": \"rootplc\", \"args\": [\"mcp\"] }\n  },\n  \"context\": { \"fileName\": [\"AGENTS.md\"] }\n}\n";
        match self {
            Host::Claude => vec![
                (".mcp.json", MCP_JSON),
                (
                    "CLAUDE.md",
                    "See [AGENTS.md](AGENTS.md). It applies to Claude Code as well.\n",
                ),
            ],
            Host::Gemini => vec![(".gemini/settings.json", GEMINI_STYLE)],
            Host::Qwen => vec![(".qwen/settings.json", GEMINI_STYLE)],
            Host::Cursor => vec![(".cursor/mcp.json", MCP_JSON)],
            Host::Codex => vec![(
                ".codex/config.toml",
                "[mcp_servers.rootplc]\ncommand = \"rootplc\"\nargs = [\"mcp\"]\n",
            )],
        }
    }
}

/// What happened to one file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outcome {
    /// Written.
    Created(PathBuf),
    /// Exists and already mentions rootplc.
    AlreadyConfigured(PathBuf),
    /// Exists without rootplc; merge this snippet by hand.
    MergeByHand(PathBuf, &'static str),
}

/// Write the configuration of `hosts` into the project at `dir`.
pub fn configure(dir: &Path, hosts: &[Host]) -> Result<Vec<Outcome>, String> {
    let mut out = Vec::new();
    for h in hosts {
        for (rel, text) in h.files() {
            let path = dir.join(rel);
            if let Ok(existing) = std::fs::read_to_string(&path) {
                let lower = existing.to_lowercase();
                let configured = if rel.ends_with(".md") {
                    lower.contains("agents.md")
                } else {
                    lower.contains("rootplc")
                };
                out.push(if configured {
                    Outcome::AlreadyConfigured(path)
                } else {
                    Outcome::MergeByHand(path, text)
                });
                continue;
            }
            if let Some(parent) = path.parent() {
                std::fs::create_dir_all(parent)
                    .map_err(|e| format!("{}: {e}", parent.display()))?;
            }
            std::fs::write(&path, text).map_err(|e| format!("{}: {e}", path.display()))?;
            out.push(Outcome::Created(path));
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_host_lists() {
        assert_eq!(Host::parse_list("all").map(|v| v.len()), Ok(5));
        assert_eq!(
            Host::parse_list("Claude, cursor,claude"),
            Ok(vec![Host::Claude, Host::Cursor])
        );
        assert!(Host::parse_list("vim").is_err());
        assert!(Host::parse_list("").is_err());
    }

    #[test]
    fn writes_once_and_never_overwrites() {
        let dir = std::env::temp_dir().join(format!("rootplc-agents-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).expect("temp dir");
        std::fs::write(dir.join("CLAUDE.md"), "# my own notes\n").expect("write");
        let first = configure(&dir, Host::ALL).expect("configure");
        let created = first
            .iter()
            .filter(|o| matches!(o, Outcome::Created(_)))
            .count();
        assert_eq!(created, 5);
        assert!(
            first
                .iter()
                .any(|o| matches!(o, Outcome::MergeByHand(p, _) if p.ends_with("CLAUDE.md")))
        );
        assert_eq!(
            std::fs::read_to_string(dir.join("CLAUDE.md")).expect("read"),
            "# my own notes\n"
        );
        let again = configure(&dir, &[Host::Claude, Host::Codex]).expect("again");
        assert!(matches!(again[0], Outcome::AlreadyConfigured(_)));
        assert!(matches!(again[2], Outcome::AlreadyConfigured(_)));
        let _ = std::fs::remove_dir_all(&dir);
    }
}
