# RootPLC (根控)

An open, agent-first IEC 61131-3 toolchain and runtime. AI agents use it to
write, compile, test, simulate, verify and deploy PLC programs. Apache-2.0.

> Status: **Phase 0, early preview.** `init`, `check`, `test`, `run`,
> `explain` and the MCP server work. `build`, `sim`, `verify`, `import` and
> `deploy` come later. The language spec and conformance suite are the ground truth.

## Install

```sh
# Linux / macOS
curl -fsSL https://raw.githubusercontent.com/xiaojunyang0805/RootPLC/main/scripts/install.sh | sh
# Windows (PowerShell)
irm https://raw.githubusercontent.com/xiaojunyang0805/RootPLC/main/scripts/install.ps1 | iex
# Any platform with Rust
cargo install rootplc            # after the first release
cargo install --locked --git https://github.com/xiaojunyang0805/RootPLC rootplc
# Agent hosts that launch MCP servers with npx or uvx
npx -y rootplc mcp
uvx rootplc mcp
```

The scripts download a checksummed release binary, or build with cargo if no
release exists for the platform yet.

## Use

```sh
rootplc init my-machine && cd my-machine
rootplc check . --json     # diagnostics with stable codes, positions and fix hints
rootplc test .             # runs TEST ... END_TEST blocks in a deterministic VM
rootplc test . --mutate    # mutation score: do the tests catch small changes to the code?
rootplc evidence . --markdown   # evidence pack for sign-off: hashes, tests, mutation score, verdict
rootplc run . --cycles 100 --cycle-ms 10
rootplc explain RP0103     # the spec rule behind a diagnostic
```

Agents: connect `rootplc mcp` to your host ([agent/mcp](agent/mcp/README.md));
the skill is in [agent/skills/rootplc-st](agent/skills/rootplc-st/SKILL.md).
Command reference: [docs/cli](docs/cli/README.md).

## Repository map

| Path | What it holds |
|---|---|
| `crates/` | Rust workspace: compiler, VM, simulator, MCP server, runtime ([ARCHITECTURE.md](ARCHITECTURE.md)) |
| `spec/` | The RootPLC language and profile spec, the ground truth |
| `conformance/` | Conformance cases that every merge must pass |
| `bench/` | PLC-Agent-Bench task format and tasks |
| `eval/` | Agent evaluation harness (pick rate, success rate) |
| `agent/` | SKILL.md set, AGENTS.md template, MCP configs, host plugins |
| `docs/` | Agent-readable docs (`.md` only, `llms.txt`) |
| `examples/` | Example PLC projects, each compiled and tested in CI |
| `runtime-c/` | Thin C runtime shim for MCU/RTOS targets (Phase 4) |
| `web/playground/` | Browser playground (VM in Wasm) |

## Licence

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE). Contributions are
accepted under the DCO ([CONTRIBUTING.md](CONTRIBUTING.md)).

The CLI is always `rootplc`. Do not shorten it to "rPLC", which is the name of
another vendor's product.
