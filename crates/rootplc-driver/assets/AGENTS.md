# AGENTS.md

This is a RootPLC project: IEC 61131-3 Structured Text, checked and tested
with `rootplc`.

- Code is in `src/`, tests (`TEST ... END_TEST`) in `tests/`.
- Patterns: `rootplc examples <words>` gives verified code for timers, edges,
  counters, state machines and interlocks; `--show <id>` prints one.
- Check: `rootplc check . --json`. Fix every diagnostic; `rootplc explain <code>`
  quotes the rule.
- Write IEC 61131-3 forms (`END_IF;`, `TOD#12:00:00`). A warning RP0133,
  RP0134 or RP0135 marks a CODESYS / TwinCAT form; keep one only when the
  project must stay vendor-specific.
- Test: `rootplc test . --json`. Every program change needs a passing test.
- Test the tests: `rootplc test . --mutate --json` changes the code one token
  at a time; add a test for every surviving change it lists.
- Inspect: `rootplc run . --cycles 10 --json` shows variable values.
- Existing code: `rootplc coverage <dir> --json` says which files are
  portable, which use vendor constructs, and why.
- Same behaviour? `rootplc diff . --reference OLD --unit NEW --json` runs
  two function blocks on the same inputs and lists where outputs differ
  (after a refactoring, or against a RootBlocks block).
- The MCP server `rootplc mcp` offers the same as tools.
- Done means: check clean, all tests pass, and a high mutation score.
  Finish with `rootplc evidence . --markdown` and show the verdict.
- Never run `rootplc deploy`. A human approves deployments.
