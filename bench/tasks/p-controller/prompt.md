# Proportional controller with output limits

Write `FUNCTION P_Control : REAL` with inputs
`setpoint`, `actual`, `kp`, `out_min`, `out_max : REAL`.

It returns `kp * (setpoint - actual)`, limited to the range `out_min ..
out_max`.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
