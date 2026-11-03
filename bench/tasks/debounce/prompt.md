# Input debounce

Write `FUNCTION_BLOCK FB_Debounce` with
- inputs `raw : BOOL`, `delay : TIME`,
- output `out : BOOL` (initially FALSE).

`out` takes the value of `raw` only after `raw` has kept that value
continuously for at least `delay`. Shorter changes (bounces) are ignored.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
