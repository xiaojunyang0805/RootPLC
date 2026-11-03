# Palletizer counter

Write `PROGRAM PRG_Palletizer` with
- inputs `box`, `reset : BOOL`,
- outputs `boxes_in_layer`, `layers : INT`, `layer_done`, `pallet_done : BOOL`.

Each rising edge of `box` counts one box. Six boxes make a layer: on the
sixth box, `boxes_in_layer` returns to 0, `layers` increases by one and
`layer_done` is TRUE for that cycle only. After 4 layers `pallet_done`
becomes TRUE and stays TRUE; further boxes are not counted. `reset` clears
all counters and `pallet_done`.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
