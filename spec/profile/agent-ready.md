# Agent-Ready PLC Profile

*Status: placeholder. Target v0.1 in Phase 3, v1.0 in Phase 4.*

Defines what a runtime must offer to carry the "RootPLC Agent-Ready" mark:
1. Runtime ABI (`rootplc-abi`): program image, I/O image, variable table, force masks.
2. Agent API (MCP/HTTP): read, trace and explain are open; force and deploy are gated by human approval.
3. Device description format.
4. Security: signed artifacts, audit log, IEC 62443-4-2 SL-C2 design.
