PROGRAM PRG_Tank
VAR_INPUT
    level : REAL;
END_VAR
VAR_OUTPUT
    pump : BOOL;
END_VAR
IF level < 20.0 THEN
    pump := TRUE;
ELSIF level > 80.0 THEN
    pump := FALSE;
END_IF;
END_PROGRAM
