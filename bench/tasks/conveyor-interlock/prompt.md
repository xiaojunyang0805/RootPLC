# Conveyor with emergency stop and guard interlock

Write `PROGRAM PRG_Conveyor` with
- inputs `start`, `stop`, `estop_ok`, `guard_closed`, `reset : BOOL`
  (`estop_ok` is TRUE while the emergency-stop circuit is healthy),
- outputs `motor`, `fault : BOOL`.

- `start` latches `motor` on, `stop` switches it off (stop wins).
- The motor may run only while `estop_ok` and `guard_closed` are TRUE.
  If either goes FALSE the motor stops and does not restart by itself.
- When `estop_ok` is FALSE, `fault` becomes TRUE and stays TRUE until
  `reset` is TRUE while `estop_ok` is TRUE again. While `fault` is TRUE,
  `start` is ignored.
- An open guard stops the motor but does not set `fault`.

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
