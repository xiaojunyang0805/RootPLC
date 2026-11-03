# Pulse counter

Write `FUNCTION_BLOCK FB_PulseCounter` with
- inputs `pulse`, `reset : BOOL`,
- output `count : INT`.

`count` increases by one on every rising edge of `pulse` (FALSE to TRUE).
Holding `pulse` TRUE counts once. While `reset` is TRUE, `count` is 0 and
edges are not counted.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
