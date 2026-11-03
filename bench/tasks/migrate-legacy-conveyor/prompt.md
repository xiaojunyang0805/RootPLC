# Port and fix a legacy conveyor program

This program comes from an old machine. It was written for a lenient
compiler and it has never been tested. Port it to strict IEC 61131-3
Structured Text and make it safe. Required behaviour:

- `motor` is latched on by `start` and switched off by `stop`.
- **`stop` and a lost emergency stop (`estop_ok` = FALSE) always stop the
  motor, even while `start` is held.** After an emergency stop, the motor
  only restarts with a new `start` once `estop_ok` is TRUE again.
- `speed_cmd` is `speed_setpoint` limited to 0..100 (the drive accepts
  only 0..100); it is 0 while the motor is off.
- `jam_alarm` turns on when `jam_sensor` has been TRUE for 3 s, and stays on
  until `reset` is TRUE. While `jam_alarm` is on, the motor is off.

Keep the name `PROGRAM PRG_Conveyor` with inputs `start`, `stop`,
`estop_ok`, `jam_sensor`, `reset : BOOL`, `speed_setpoint : INT` and outputs
`motor`, `jam_alarm : BOOL`, `speed_cmd : SINT`.

```
PROGRAM PRG_Conveyor
VAR_INPUT start, stop, estop_ok : BOOL; speed_setpoint : INT; END_VAR
VAR_OUTPUT motor : BOOL; speed_cmd : SINT; jam_alarm : BOOL; END_VAR
VAR jam_timer : TON; jam_sensor : BOOL; END_VAR
motor := start OR motor AND NOT stop AND estop_ok;
speed_cmd := speed_setpoint;
jam_timer(IN := jam_sensor, PT := 3000);
IF jam_timer.Q THEN jam_alarm := 1; END_IF
END_PROGRAM
```

## Rules

- Write IEC 61131-3 Structured Text in `src/` (any file name ending in `.st`).
- Use exactly the names, types and interface given above: hidden tests call it.
- Visible tests are in `tests/visible_tests.st`. Hidden tests check more behaviour.
- One call of a program or function-block instance is one PLC cycle.
