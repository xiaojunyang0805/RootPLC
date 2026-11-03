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
