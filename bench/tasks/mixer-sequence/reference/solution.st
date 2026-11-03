PROGRAM PRG_Mixer
VAR_INPUT
    start, level_full, level_empty : BOOL;
END_VAR
VAR_OUTPUT
    fill_valve, mixer, drain_valve : BOOL;
    phase : INT;
END_VAR
VAR
    t : TON;
END_VAR
CASE phase OF
    0:
        IF start THEN
            phase := 1;
        END_IF
    1:
        IF level_full THEN
            phase := 2;
        END_IF
    2:
        t(IN := TRUE, PT := T#10s);
        IF t.Q THEN
            phase := 3;
            t(IN := FALSE);
        END_IF
    3:
        IF level_empty THEN
            phase := 0;
        END_IF
END_CASE
fill_valve := phase = 1;
mixer := phase = 2;
drain_valve := phase = 3;
END_PROGRAM
