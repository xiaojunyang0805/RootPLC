# Star-delta motor starter

Write `FUNCTION_BLOCK FB_StarDelta` with
- inputs `start`, `stop : BOOL` (`start` may be a one-cycle pulse),
- outputs `main`, `star`, `delta : BOOL`.

On `start`: `main` and `star` switch on. After 5 s `star` switches off; after
a further pause of 100 ms (`main` stays on) `delta` switches on. The motor
then runs on `main` + `delta` until `stop`, which switches everything off and
has priority over `start`. `star` and `delta` must never be on at the same
time. `start` while running has no effect.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
