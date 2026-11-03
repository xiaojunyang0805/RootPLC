PROGRAM PRG_Motor
VAR_INPUT
    start, stop : BOOL;
END_VAR
VAR_OUTPUT
    running : BOOL;
END_VAR
running := (start OR running) AND NOT stop;
END_PROGRAM
