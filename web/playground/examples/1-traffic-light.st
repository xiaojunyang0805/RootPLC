(* title: Traffic light (timers, CASE)
   hint: Press Run plant and switch enable on: green 10 s, yellow 3 s, red 12 s. Press Test to run the TEST block in virtual time. *)
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
    END_IF
    CASE phase OF
        0: pt := T#10s;
        1: pt := T#3s;
    ELSE
        pt := T#12s;
    END_CASE
    tmr(IN := TRUE, PT := pt);
    IF tmr.Q THEN
        phase := (phase + 1) MOD 3;
        CASE phase OF
            0: pt := T#10s;
            1: pt := T#3s;
        ELSE
            pt := T#12s;
        END_CASE
        tmr(IN := FALSE);
        tmr(IN := TRUE, PT := pt);
    END_IF
END_IF
green := enable AND phase = 0;
yellow := enable AND phase = 1;
red := NOT enable OR phase = 2;
END_PROGRAM

TEST cycle_reaches_yellow
VAR uut : PRG_TrafficLight; i : INT; END_VAR
FOR i := 1 TO 115 DO
    uut(enable := TRUE);
    ADVANCE(T#100ms);
END_FOR
uut(enable := TRUE);
ASSERT_TRUE(uut.yellow);
ASSERT_FALSE(uut.red OR uut.green);
END_TEST
