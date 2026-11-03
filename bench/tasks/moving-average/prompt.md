# Moving average

Write `FUNCTION_BLOCK FB_MovingAverage` with input `x : REAL` and output
`avg : REAL`.

Each call adds one sample `x`. `avg` is the mean of the last 4 samples; while
fewer than 4 samples have been given, it is the mean of all samples so far.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
