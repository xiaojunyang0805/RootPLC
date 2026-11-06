---
name: rootplc-st
description: Write, check and test IEC 61131-3 Structured Text (PLC code) with the rootplc toolchain. Use for any PLC, ST, CODESYS-style or TwinCAT-style programming task.
---

# Writing PLC code with rootplc

Use the MCP tools (`rootplc_check`, `rootplc_test`, `rootplc_run`,
`rootplc_diff`, `rootplc_evidence`, `rootplc_explain`, `rootplc_examples`,
`rootplc_coverage`) when available; otherwise the same commands with `--json`.

## Loop

1. No `rootplc.toml` yet? Run `rootplc init` (creates `src/`, `tests/`, a
   passing example test and AGENTS.md).
2. Common pattern (timer, edge, counter, state machine, interlock)? Call
   `rootplc_examples` (or `rootplc examples <words>`) first: every example
   compiles and passes its tests in this toolchain version.
3. Write ST in `src/`. Write `TEST ... END_TEST` blocks in `tests/`. For a
   typical job (motor, valve, PID, step chain, alarm, conveyor zone …) use a
   verified RootBlocks block (`--library RootBlocks`, cards in `blocks/`)
   instead of writing it again; `rootplc diff` checks that your own block
   behaves like one.
4. `rootplc check . --json` until `ok` is true. Fix every diagnostic. Each has
   a stable code (RPnnnn), a 1-based line and column, and often a `hint`.
   `rootplc explain <code>` quotes the spec rule.
5. `rootplc test . --json` until every test passes. Failures give the
   assertion's location; faults (DIV_BY_ZERO, INDEX, RANGE, NULL_REF,
   WATCHDOG) give where execution stopped.
6. `rootplc test . --mutate --json` (MCP: `rootplc_test` with `mutate: true`)
   checks the tests themselves: each listed survivor is a change to the code
   that no test notices. Add a test for each until the score is high.
7. `rootplc evidence . --markdown` (MCP: `rootplc_evidence`) gives the
   evidence pack: input hashes, check, tests, mutation score and a verdict.
8. Report success only when check is clean, all tests pass and the evidence
   verdict is `verified`. Show the test names you added and the mutation score.
9. Never deploy to a real PLC. A human approves deployments.

## Language notes (strict, like the IEC standard)

- No implicit narrowing: `SINT := INT` is RP0103. Use `INT_TO_SINT(x)` or
  `TO_SINT(x)`. Integer to BOOL, enum to INT and DINT to REAL also need an
  explicit conversion.
- Conditions must be BOOL: `IF count THEN` is an error; write `IF count <> 0 THEN`.
- Durations are literals: `PT := T#500ms`, not `PT := 500`.
- Keywords and type names cannot be names (`on`, `time`, `dt`, `string` are reserved).
- Every statement ends with `;`.
- Standard blocks: TON, TOF, TP, R_TRIG, F_TRIG, CTU, CTD, CTUD, SR, RS.
- A TON that times one CASE step must be called with `IN := FALSE` before
  the step changes (or every cycle outside the CASE), otherwise it fires
  early next time: warning RP0304.

## Tests

```
TEST start_latches
VAR
    uut : PRG_Main;          (* programs and function blocks can be instantiated *)
END_VAR
uut(start := TRUE);          (* one call = one PLC cycle *)
ASSERT_TRUE(uut.running);    (* tests may read every variable, also internal ones *)
ASSERT_EQ(3, uut.count);
END_TEST
```
