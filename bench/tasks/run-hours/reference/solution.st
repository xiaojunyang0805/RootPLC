FUNCTION_BLOCK FB_RunHours
VAR_INPUT
    running, reset : BOOL;
END_VAR
VAR_OUTPUT
    hours : UDINT;
    minutes : INT;
END_VAR
VAR
    t : TON;
END_VAR
IF reset THEN
    hours := 0;
    minutes := 0;
    t(IN := FALSE);
ELSE
    t(IN := running, PT := T#1m);
    IF t.Q THEN
        t(IN := FALSE);
        t(IN := running, PT := T#1m);
        minutes := minutes + 1;
        IF minutes >= 60 THEN
            minutes := 0;
            hours := hours + 1;
        END_IF
    END_IF
END_IF
END_FUNCTION_BLOCK
