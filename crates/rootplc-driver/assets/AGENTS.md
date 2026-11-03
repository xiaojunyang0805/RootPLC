# AGENTS.md

This is a RootPLC project: IEC 61131-3 Structured Text, checked and tested
with `rootplc`.

- Code is in `src/`, tests (`TEST ... END_TEST`) in `tests/`.
- Check: `rootplc check . --json`. Fix every diagnostic; `rootplc explain <code>`
  quotes the rule.
- Test: `rootplc test . --json`. Every program change needs a passing test.
- Inspect: `rootplc run . --cycles 10 --json` shows variable values.
- The MCP server `rootplc mcp` offers the same as tools.
- Done means: check clean and all tests pass.
- Never run `rootplc deploy`. A human approves deployments.
