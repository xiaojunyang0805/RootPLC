(* spec: [statements.case.timer]
   expect: warning RP0304 *)
(* The timeout path leaves step 1 while tTimeout still has IN = TRUE: after
   Reset, the next homing faults on its first call (found in real code). *)
FUNCTION_BLOCK FB_Home
VAR_INPUT start : BOOL; atHome : BOOL; reset : BOOL; END_VAR
VAR_OUTPUT move : BOOL; fault : BOOL; END_VAR
VAR nStep : INT; tTimeout : TON; END_VAR
CASE nStep OF
    0:
        IF start THEN
            nStep := 1;
        END_IF;
    1:
        tTimeout(IN := TRUE, PT := T#10s);
        IF atHome THEN
            tTimeout(IN := FALSE);
            nStep := 2;
        ELSIF tTimeout.Q THEN
            nStep := 99;
        END_IF;
    2:
        IF reset THEN
            nStep := 0;
        END_IF;
    99:
        IF reset THEN
            nStep := 0;
        END_IF;
END_CASE;
move := nStep = 1;
fault := nStep = 99;
END_FUNCTION_BLOCK
