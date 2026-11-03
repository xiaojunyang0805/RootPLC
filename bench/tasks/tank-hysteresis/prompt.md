# Tank pump with hysteresis

Write `PROGRAM PRG_Tank` with
- input `level : REAL` (percent),
- output `pump : BOOL` (initially FALSE).

The pump starts when `level` is below 20.0 and stops when `level` is above
80.0. Between those limits it keeps its state.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
