# Analog input scaling

Write `FUNCTION ScaleAnalog : REAL` with inputs `raw : INT`, `lo`, `hi : REAL`.

`raw` comes from a 0..27648 analog input card. Map it linearly to `lo .. hi`
(0 gives `lo`, 27648 gives `hi`). Values below 0 give `lo`; values above
27648 give `hi`.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
