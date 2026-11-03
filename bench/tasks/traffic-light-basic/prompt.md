# Traffic light

Write `PROGRAM PRG_TrafficLight` with
- input `enable : BOOL`,
- outputs `red`, `yellow`, `green : BOOL`.

When enabled, the light cycles green 10 s, yellow 3 s, red 12 s, and repeats.
When `enable` becomes TRUE, the cycle starts with green. When disabled, only
red is on. Exactly one output is TRUE at any time.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
