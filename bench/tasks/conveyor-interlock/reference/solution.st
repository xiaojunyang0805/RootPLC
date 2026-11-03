PROGRAM PRG_Conveyor
VAR_INPUT
    start, stop, estop_ok, guard_closed, reset : BOOL;
END_VAR
VAR_OUTPUT
    motor, fault : BOOL;
END_VAR
IF NOT estop_ok THEN
    fault := TRUE;
ELSIF reset THEN
    fault := FALSE;
END_IF
IF fault OR NOT guard_closed OR stop THEN
    motor := FALSE;
ELSIF start THEN
    motor := TRUE;
END_IF
END_PROGRAM
