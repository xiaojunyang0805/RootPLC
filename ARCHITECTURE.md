# Architecture

This file maps the target architecture onto the repository. Each crate states the phase it belongs to. Crates for later
phases exist only as stubs, so that the boundaries are fixed early.

```
 agents --> MCP | SKILL.md | AGENTS.md | CLI --json
                 |                          |
           rootplc-mcp                 rootplc-cli        (thin front doors)
                 +------------+-------------+
                        rootplc-driver                    (every command lives here)
   +-------------+-----------+--+--------------+---------------+
 front end     back ends     verification    interchange     simulation
 syntax        vm            testing         interchange     sim
 sema          codegen-c     verify          graph
 diag, stdlib
   +-------- rootplc-abi (program image, I/O image, variable table) --------+
                                  |
                rootplc-runtime -- rootplc-fieldbus
                runtime-c/  (C shim for MCU / RTOS targets)
```

## Crates

| Crate | Layer | Phase | Responsibility |
|---|---|---|---|
| `rootplc-diag` | Front end | 1 | Diagnostic type, stable codes (`RP0001`...), fix hints, JSON form, `explain` texts |
| `rootplc-syntax` | Front end | 1 | Lexer, parser, lossless syntax tree for ST, plus the text forms of SFC/LD/FBD |
| `rootplc-sema` | Front end | 1 | Name resolution, type checking, typed IR (the input to every back end) |
| `rootplc-stdlib` | Front end | 1 | Clean-room standard library written in ST: timers, counters, edges, strings, math |
| `rootplc-vm` | Back end | 1 | Bytecode compiler and interpreter. Used by `test`, `run`, `sim` and the Wasm playground |
| `rootplc-testing` | Verification | 1 | `TEST ... END_TEST` blocks, runner, JSON results |
| `rootplc-driver` | Orchestration | 1 | Project model (`rootplc.toml`) and the implementation of every command. The CLI and MCP call only this crate |
| `rootplc-cli` (package `rootplc`) | Front door | 1 | The `rootplc` binary: argument parsing and output formatting only. `rootplc mcp` starts the MCP server |
| `rootplc-mcp` | Front door | 1 | MCP server (stdio and HTTP), exposing driver commands as tools |
| `rootplc-wasm` | Front door | 1 | Wasm bindings for the browser playground |
| `rootplc-codegen-c` | Back end | 2 | Typed IR to portable C99 against `rootplc-abi` |
| `rootplc-verify` | Verification | 2 | Properties from ST pragmas, CBMC run on generated C, counterexample traces |
| `rootplc-sim` | Simulation | 2 | Virtual time, FMI 2/3 plants, simulated EtherCAT slaves, scenarios, replay, trace diff |
| `rootplc-interchange` | Interchange | 2 | PLCopen XML (IEC 61131-10) and TwinCAT XML import/export |
| `rootplc-graph` | Interchange | 2 | SFC/LD/FBD canonical text/JSON and the layout model for the read-only renderer |
| `rootplc-abi` | Runtime | 2-3 | The runtime ABI shared by codegen-c, the Rust runtime and the C shim |
| `rootplc-conformance` | Quality | 0 | Loads `conformance/cases`, checks them against the spec rule IDs and `spec/diagnostics.toml`; later runs them against the compiler |
| `rootplc-runtime` | Runtime | 3 | PREEMPT_RT scheduler, program loading, force/trace, online change, signed deploy, agent API |
| `rootplc-fieldbus` | Runtime | 3 | Transport traits; EtherCAT (ethercrab), Modbus, OPC UA, CANopen adapters |

## Dependency rules

1. Dependencies point downward only: front doors -> driver -> layers -> abi.
2. `rootplc-cli` and `rootplc-mcp` hold no logic. A feature is added to
   `rootplc-driver` once, and both front doors get it.
3. Every back end consumes the typed IR from `rootplc-sema`, never the syntax tree.
4. `rootplc-runtime` does not depend on the compiler. It sees programs only
   through `rootplc-abi`.
5. `unsafe` is denied workspace-wide. It may be allowed only in modules marked
   `#[allow(unsafe_code)]` inside `rootplc-runtime` and `rootplc-fieldbus`,
   and each such module needs a Kani proof or a written justification.
6. No GPL/LGPL code in-process (`deny.toml`). GPL tools run only as optional
   external programs.

## Non-Rust parts

| Path | Notes |
|---|---|
| `runtime-c/` | C99 shim implementing `rootplc-abi` for Zephyr, RT-Thread and ESP32. A few thousand lines at most, verified with CBMC |
| `crates/rootplc-stdlib/st/` | Standard library sources in ST, embedded at build time |
| `web/playground/` | Static front end over `rootplc-wasm` |
