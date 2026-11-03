FUNCTION_BLOCK FB_Blink
VAR_INPUT
    enable : BOOL;
    period : TIME;
END_VAR
VAR_OUTPUT
    out : BOOL;
END_VAR
VAR
    t : TON;
    running : BOOL;
END_VAR
IF enable THEN
    IF NOT running THEN
        running := TRUE;
        out := TRUE;
        t(IN := FALSE);
    END_IF
    t(IN := TRUE, PT := period / 2);
    IF t.Q THEN
        out := NOT out;
        t(IN := FALSE);
        t(IN := TRUE, PT := period / 2);
    END_IF
ELSE
    running := FALSE;
    out := FALSE;
    t(IN := FALSE);
END_IF
END_FUNCTION_BLOCK
