# Index of the largest value

Write `FUNCTION MaxIndex : INT` with input `values : ARRAY[1..8] OF INT`.

Return the index (1..8) of the largest element. If several elements share the
largest value, return the smallest such index.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
