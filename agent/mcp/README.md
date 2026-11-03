# Connecting agent hosts

Every host runs the same stdio server: `rootplc mcp`. Install `rootplc` first
(see the README), then add the server to your host. Restart the host afterwards.

The server offers four read-only tools: `rootplc_check`, `rootplc_test`,
`rootplc_run`, `rootplc_explain`. They never write files or touch hardware.

## Claude Code

```sh
claude mcp add rootplc -- rootplc mcp
```
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
`rootplc run --json`, `rootplc explain <code> --json`.
