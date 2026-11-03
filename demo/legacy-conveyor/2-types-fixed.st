(* The "obvious" fix: make the compiler happy, change nothing else. *)
PROGRAM PRG_Conveyor
VAR_INPUT start, stop, estop_ok, jam_sensor, reset : BOOL; speed_setpoint : INT; END_VAR
VAR_OUTPUT motor : BOOL; speed_cmd : SINT; jam_alarm : BOOL; END_VAR
VAR jam_timer : TON; END_VAR
motor := start OR motor AND NOT stop AND estop_ok;
speed_cmd := INT_TO_SINT(speed_setpoint);
jam_timer(IN := jam_sensor, PT := T#3s);
IF jam_timer.Q THEN jam_alarm := TRUE; END_IF
END_PROGRAM
