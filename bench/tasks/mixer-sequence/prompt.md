# Fill, mix and drain sequence

Write `PROGRAM PRG_Mixer` with
- inputs `start`, `level_full`, `level_empty : BOOL`,
- outputs `fill_valve`, `mixer`, `drain_valve : BOOL` and `phase : INT`.

Phases (`phase` shows the current one):
- 0 idle: all outputs off. `start` begins phase 1.
- 1 filling: `fill_valve` on until `level_full`, then phase 2.
- 2 mixing: `mixer` on for 10 s, then phase 3.
- 3 draining: `drain_valve` on until `level_empty`, then phase 0.

`start` is ignored outside phase 0. Only the output of the current phase is on.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
