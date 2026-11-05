# Connecting agent hosts

Every host runs the same stdio server: `rootplc mcp`. Install `rootplc` first
(see the README), then add the server to your host. Restart the host afterwards.

The server offers seven read-only tools: `rootplc_check`, `rootplc_test`
(with `mutate: true` for the mutation score), `rootplc_run`,
`rootplc_evidence` (the evidence pack for sign-off), `rootplc_explain`,
`rootplc_examples` (verified ST patterns) and `rootplc_coverage` (portable /
dialect / dependent / blocked per file).
They never write files or touch hardware. It also serves the agent guide, the
spec chapters, the diagnostic registry and the examples as resources, and the
prompts `write_and_verify`, `fix_diagnostics` and `port_legacy`.

Fastest setup inside a project: `rootplc init --agent claude` (or `gemini`,
`qwen`, `cursor`, `codex`, `all`) writes the files below for you and never
overwrites existing ones.

## Claude Code

```sh
claude mcp add rootplc -- rootplc mcp
```
or install the plugin (MCP server plus skills), see
[`../plugins/claude-code`](../plugins/claude-code/README.md),
or add [`claude-code.json`](claude-code.json) as `.mcp.json` in the project.

## Codex CLI

`~/.codex/config.toml`:
```toml
[mcp_servers.rootplc]
command = "rootplc"
args = ["mcp"]
```

## Gemini CLI and Qwen Code

`~/.gemini/settings.json` (Gemini CLI) or `~/.qwen/settings.json` (Qwen Code), or
the same file inside the project:
```json
{ "mcpServers": { "rootplc": { "command": "rootplc", "args": ["mcp"] } } }
```

## Cursor

`.cursor/mcp.json` in the project, or `~/.cursor/mcp.json`:
```json
{ "mcpServers": { "rootplc": { "command": "rootplc", "args": ["mcp"] } } }
```

## Other hosts

Any MCP host that runs stdio servers works with command `rootplc` and argument
`mcp`. Hosts still to verify in the eval harness (E2): Kimi CLI, DeepSeek
harness, Lingma, Trae, GitHub Copilot.

## Without MCP

Every tool is also a CLI command with JSON output, for hosts that only run
shell commands: `rootplc check --json`, `rootplc test --json`,
`rootplc run --json`, `rootplc explain <code> --json`,
`rootplc examples <words> --json`, `rootplc coverage <dir> --json`.
