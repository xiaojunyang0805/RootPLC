# rootplc

Agent-first toolchain for IEC 61131-3 Structured Text (PLC code). AI agents
and engineers use it to check, test and run PLC programs.

```sh
rootplc init my-machine && cd my-machine
rootplc check . --json     # diagnostics with stable codes, positions and fix hints
rootplc test .             # TEST ... END_TEST blocks in a deterministic VM
rootplc run . --cycles 100 --cycle-ms 10
rootplc explain RP0103     # the spec rule behind a diagnostic
rootplc mcp                # MCP server for agent hosts (stdio)
```

Install: `cargo install rootplc`, `npx -y rootplc`, `uvx rootplc`, or the
one-line installers in the repository README.

Status: early preview (Phase 0). Spec, conformance suite and source:
<https://github.com/xiaojunyang0805/RootPLC>. Licence: Apache-2.0.

<!-- MCP Registry ownership marker for the PyPI package: -->
mcp-name: com.rootplc/rootplc
