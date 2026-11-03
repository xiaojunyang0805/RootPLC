PROGRAM PRG_Conveyor
VAR_INPUT start, stop, estop_ok : BOOL; speed_setpoint : INT; END_VAR
VAR_OUTPUT motor : BOOL; speed_cmd : SINT; jam_alarm : BOOL; END_VAR
VAR jam_timer : TON; jam_sensor : BOOL; END_VAR
motor := start OR motor AND NOT stop AND estop_ok;
speed_cmd := speed_setpoint;
jam_timer(IN := jam_sensor, PT := 3000);
IF jam_timer.Q THEN jam_alarm := 1; END_IF
END_PROGRAM
