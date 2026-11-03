---
name: rootplc-st
description: Write, compile and test IEC 61131-3 Structured Text with the rootplc toolchain. Use for any PLC or ST programming task.
---

# Writing PLC code with rootplc

1. If no `rootplc.toml` exists, run `rootplc init`.
2. Write ST in `src/`, and TEST blocks in `tests/`.
3. Loop until clean: `rootplc check --json`. Fix every diagnostic; `rootplc explain <code>` explains it.
4. Run `rootplc test --json`. Do not report success until all tests pass.
5. Never run `rootplc deploy` yourself. It needs a human to approve.
