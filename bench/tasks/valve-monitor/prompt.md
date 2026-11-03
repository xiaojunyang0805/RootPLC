# Valve feedback monitor

Write `FUNCTION_BLOCK FB_ValveMonitor` with inputs `cmd_open`, `fb_open`,
`fb_closed : BOOL`, `timeout : TIME`, `reset : BOOL` and output `fault : BOOL`.

The feedback matches the command when `cmd_open` is TRUE with `fb_open` TRUE
and `fb_closed` FALSE, or `cmd_open` is FALSE with `fb_closed` TRUE and
`fb_open` FALSE. `fault` becomes TRUE
- when the feedback has not matched the command for longer than `timeout`, or
- immediately when `fb_open` and `fb_closed` are both TRUE.

`fault` stays TRUE until `reset` is TRUE while no fault condition is present.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
