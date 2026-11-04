# PLC-Agent-Bench baseline report

*Generated 2026-11-04 from runs g0-hard-claude-20261104. 6 tasks; 36 agent runs.*

## Headline

Verified-correct = compiles, passes the visible tests and every hidden test. Mutation score = share of seeded faults the agent's own tests catch.

| Host | Mode | Runs | Compile | Verified-correct | Mean score | Wrote tests | Mutation score | Used rootplc | Mean time |
|---|---|---|---|---|---|---|---|---|---|
| claude-code | without | 18 | 94% | **94%** | 0.94 | 0% | n/a | 0% | 42 s |
| claude-code | with | 18 | 100% | **100%** | 1.00 | 100% | 63% | 100% | 55 s |

## Effect of RootPLC (with minus without)

| Host | Compile | Verified-correct | Mean score |
|---|---|---|---|
| claude-code | +6 pts | **+6 pts** | +0.06 |

## By difficulty

| Host | Mode | easy | medium | hard |
|---|---|---|---|---|
| claude-code | without | - | - | 17/18 |
| claude-code | with | - | - | 18/18 |

## Strict IEC 61131-3

Tasks that ask for strict IEC 61131-3 count a solution with a CODESYS / TwinCAT form (a RootPLC portability warning) as not verified-correct.

| Host | Mode | Runs | IEC clean | Correct behaviour but a vendor form |
|---|---|---|---|---|
| claude-code | without | 18 | 94% | 0 |
| claude-code | with | 18 | 100% | 0 |

## By task

OK = verified-correct, v = correct behaviour but not strict IEC, c = compiles only, - = does not compile.

| Task | Category | Difficulty | claude-code without | claude-code with |
|---|---|---|---|---|
| batch-totalizer | process | hard | 3/3 OK | 3/3 OK |
| fifo-remove | logic | hard | 3/3 OK | 3/3 OK |
| filling-station | sequence | hard | 3/3 OK | 3/3 OK |
| migrate-twincat-dosing | migration | hard | 3/3 OK | 3/3 OK |
| pid-antiwindup | process | hard | 3/3 OK | 3/3 OK |
| recipe-parser | logic | hard | 2/3 OK | 3/3 OK |

## Method

- Each run starts in a fresh directory with the task prompt, an empty `src/` and the visible tests.
- Mode *with*: `rootplc` on PATH, its MCP server configured, AGENTS.md in the directory. Mode *without*: no RootPLC anywhere.
- Grading uses only the agent's `src/` plus the task's test files, run by `rootplc test`; the agent never sees the hidden tests.
- Reference solutions pass all tests; hidden tests kill most mutants of the reference (`eval/harness/validate_bench.py`).
