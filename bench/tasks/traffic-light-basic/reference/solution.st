PROGRAM PRG_TrafficLight
VAR_INPUT
    enable : BOOL;
END_VAR
VAR_OUTPUT
    red, yellow, green : BOOL;
END_VAR
VAR
    phase : INT;
    tmr : TON;
    pt : TIME;
    was_enabled : BOOL;
END_VAR
IF NOT enable THEN
    phase := 2;
    tmr(IN := FALSE);
    was_enabled := FALSE;
ELSE
    IF NOT was_enabled THEN
        phase := 0;
        tmr(IN := FALSE);
        was_enabled := TRUE;
    END_IF;
    CASE phase OF
        0: pt := T#10s;
        1: pt := T#3s;
    ELSE
        pt := T#12s;
    END_CASE;
    tmr(IN := TRUE, PT := pt);
    IF tmr.Q THEN
        phase := (phase + 1) MOD 3;
        CASE phase OF
            0: pt := T#10s;
            1: pt := T#3s;
        ELSE
            pt := T#12s;
        END_CASE;
        tmr(IN := FALSE);
        tmr(IN := TRUE, PT := pt);
    END_IF;
END_IF;
green := enable AND phase = 0;
yellow := enable AND phase = 1;
red := NOT enable OR phase = 2;
END_PROGRAM
