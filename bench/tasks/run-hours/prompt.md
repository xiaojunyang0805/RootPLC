# Running-hours meter

Write `FUNCTION_BLOCK FB_RunHours` with inputs `running`, `reset : BOOL` and
outputs `hours : UDINT`, `minutes : INT`.

While `running` is TRUE, count the running time in whole minutes. Show it as
`hours` and `minutes` (0..59). The count continues after stops (it is not
cleared when `running` goes FALSE). A partial minute at a stop may be kept
or discarded. `reset` clears it.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
