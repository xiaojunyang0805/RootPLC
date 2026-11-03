# Delayed high-level alarm

Write `PROGRAM PRG_LevelAlarm` with
- input `level_high : BOOL`,
- output `alarm : BOOL`.

`alarm` turns TRUE when `level_high` has been TRUE continuously for 5 s.
It turns FALSE as soon as `level_high` is FALSE.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
