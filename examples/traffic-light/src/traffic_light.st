PROGRAM PRG_TrafficLight
VAR_INPUT
    enable : BOOL;
END_VAR
VAR_OUTPUT
    red, yellow, green : BOOL;
END_VAR
VAR
    phase : INT := 0;      (* 0 green, 1 yellow, 2 red *)
    tmr   : TON;
END_VAR

IF NOT enable THEN
    phase := 2;
    tmr(IN := FALSE);
ELSE
    CASE phase OF
        0: tmr(IN := TRUE, PT := T#10s);
        1: tmr(IN := TRUE, PT := T#3s);
        2: tmr(IN := TRUE, PT := T#12s);
    END_CASE
    IF tmr.Q THEN
        tmr(IN := FALSE);
        phase := (phase + 1) MOD 3;
    END_IF
END_IF

green  := phase = 0;
yellow := phase = 1;
red    := phase = 2;
END_PROGRAM
