# Blinker

Write `FUNCTION_BLOCK FB_Blink` with inputs `enable : BOOL`, `period : TIME`
and output `out : BOOL`.

While `enable` is TRUE, `out` is TRUE for half of `period`, then FALSE for
half of `period`, and repeats, starting with TRUE when `enable` becomes TRUE.
While `enable` is FALSE, `out` is FALSE.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
