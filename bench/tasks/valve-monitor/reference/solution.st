FUNCTION_BLOCK FB_ValveMonitor
VAR_INPUT
    cmd_open, fb_open, fb_closed : BOOL;
    timeout : TIME;
    reset : BOOL;
END_VAR
VAR_OUTPUT
    fault : BOOL;
END_VAR
VAR
    t : TON;
    ok : BOOL;
END_VAR
ok := (cmd_open AND fb_open AND NOT fb_closed) OR (NOT cmd_open AND fb_closed AND NOT fb_open);
t(IN := NOT ok, PT := timeout);
IF (fb_open AND fb_closed) OR t.Q THEN
    fault := TRUE;
ELSIF reset THEN
    fault := FALSE;
END_IF
END_FUNCTION_BLOCK
