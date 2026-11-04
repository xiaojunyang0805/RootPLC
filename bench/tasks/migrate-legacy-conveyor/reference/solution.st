PROGRAM PRG_Conveyor
VAR_INPUT
    start, stop, estop_ok, jam_sensor, reset : BOOL;
    speed_setpoint : INT;
END_VAR
VAR_OUTPUT
    motor, jam_alarm : BOOL;
    speed_cmd : SINT;
END_VAR
VAR
    jam_timer : TON;
END_VAR
jam_timer(IN := jam_sensor, PT := T#3s);
IF jam_timer.Q THEN
    jam_alarm := TRUE;
ELSIF reset THEN
    jam_alarm := FALSE;
END_IF;
IF stop OR NOT estop_ok OR jam_alarm THEN
    motor := FALSE;
ELSIF start THEN
    motor := TRUE;
END_IF;
IF motor THEN
    speed_cmd := INT_TO_SINT(LIMIT(0, speed_setpoint, 100));
ELSE
    speed_cmd := 0;
END_IF;
END_PROGRAM
