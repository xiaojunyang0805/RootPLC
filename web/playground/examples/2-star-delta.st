(* title: Star-delta motor starter (safety interlock)
   hint: Run plant, then switch start on: star for 5 s, a 100 ms pause, then delta. Test proves star and delta are never on together. *)
FUNCTION_BLOCK FB_StarDelta
VAR_INPUT
    start, stop : BOOL;
END_VAR
VAR_OUTPUT
    main, star, delta : BOOL;
END_VAR
VAR
    st : INT;
    t : TON;
END_VAR
IF stop THEN
    st := 0;
ELSIF start AND st = 0 THEN
    st := 1;
END_IF
CASE st OF
    1:
        t(IN := TRUE, PT := T#5s);
        IF t.Q THEN
            st := 2;
            t(IN := FALSE);
            t(IN := TRUE, PT := T#100ms);
        END_IF
    2:
        t(IN := TRUE, PT := T#100ms);
        IF t.Q THEN
            st := 3;
            t(IN := FALSE);
        END_IF
ELSE
    t(IN := FALSE);
END_CASE
main := st > 0;
star := st = 1;
delta := st = 3;
END_FUNCTION_BLOCK

PROGRAM PRG_StarDelta
VAR_INPUT
    start, stop : BOOL;
END_VAR
VAR_OUTPUT
    main, star, delta : BOOL;
END_VAR
VAR
    sd : FB_StarDelta;
END_VAR
sd(start := start, stop := stop, main => main, star => star, delta => delta);
END_PROGRAM

TEST never_star_and_delta_together
VAR uut : FB_StarDelta; i, both : INT; END_VAR
uut(start := TRUE);
FOR i := 1 TO 700 DO
    uut(start := FALSE);
    IF uut.star AND uut.delta THEN both := both + 1; END_IF
    ADVANCE(T#10ms);
END_FOR
ASSERT_EQ(0, both);
ASSERT_TRUE(uut.delta);
END_TEST
