# RootPLC (根控)

An open, agent-first IEC 61131-3 toolchain and runtime. AI agents use it to
write, compile, test, simulate, verify and deploy PLC programs. Apache-2.0.

> Status: **Phase 0, Foundations.** Nothing is usable yet. The spec and the
> conformance suite come first, so AI-written code has a ground truth to meet.

```
rootplc init | check | build | test | run | sim | verify | explain | import
rootplc deploy   # always needs human approval
```

Add `--json` to any command to get machine-readable output with stable
diagnostic codes.

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
