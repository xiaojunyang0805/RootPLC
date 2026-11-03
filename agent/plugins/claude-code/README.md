# RootPLC plugin for Claude Code

Adds the RootPLC MCP server and two skills to Claude Code.

| Part | What it does |
|---|---|
| MCP server `rootplc` | Tools `rootplc_check`, `rootplc_test`, `rootplc_run`, `rootplc_explain`, `rootplc_examples`, `rootplc_coverage`; the spec and examples as resources; prompts `write_and_verify`, `fix_diagnostics`, `port_legacy` |
| Skill `rootplc-st` | The write, check, test loop for new PLC code |
| Skill `rootplc-migrate` | Measure, pin and port an existing code base |

## Install

The plugin starts `rootplc mcp`, so install the `rootplc` binary first
(see the repository README). Then, in Claude Code:

```
/plugin marketplace add xiaojunyang0805/RootPLC
/plugin install rootplc@rootplc
```

Without the plugin, `rootplc init --agent claude` writes `.mcp.json` and
`CLAUDE.md` into a project instead.

The skill and MCP files here are copies of `agent/skills/` and
`agent/mcp/claude-code.json`; the conformance suite fails if they drift.
