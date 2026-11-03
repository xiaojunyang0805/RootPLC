# Motor start/stop latch

Write `PROGRAM PRG_Motor` with
- inputs `start`, `stop : BOOL`,
- output `running : BOOL`.

Pressing `start` turns `running` on; it stays on after `start` is released.
`stop` turns it off. When both are pressed, `stop` wins. Initially `running` is FALSE.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
