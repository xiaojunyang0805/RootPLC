TEST hidden_short_pulse_ignored
VAR uut : FB_Debounce; i : INT; END_VAR
FOR i := 1 TO 3 DO
    uut(raw := TRUE, delay := T#50ms);
    ADVANCE(T#10ms);
END_FOR;
FOR i := 1 TO 20 DO
    uut(raw := FALSE, delay := T#50ms);
    ADVANCE(T#10ms);
    ASSERT_FALSE(uut.out);
END_FOR;
END_TEST

TEST hidden_not_before_delay
VAR uut : FB_Debounce; i : INT; END_VAR
FOR i := 1 TO 3 DO
    uut(raw := TRUE, delay := T#50ms);
    ADVANCE(T#10ms);
END_FOR;
uut(raw := TRUE, delay := T#50ms);
ASSERT_FALSE(uut.out);
END_TEST

TEST hidden_glitch_does_not_drop
VAR uut : FB_Debounce; i : INT; END_VAR
FOR i := 1 TO 10 DO
    uut(raw := TRUE, delay := T#50ms);
    ADVANCE(T#10ms);
END_FOR;
FOR i := 1 TO 2 DO
    uut(raw := FALSE, delay := T#50ms);
    ADVANCE(T#10ms);
END_FOR;
FOR i := 1 TO 5 DO
    uut(raw := TRUE, delay := T#50ms);
    ADVANCE(T#10ms);
    ASSERT_TRUE(uut.out);
END_FOR;
FOR i := 1 TO 10 DO
    uut(raw := FALSE, delay := T#50ms);
    ADVANCE(T#10ms);
END_FOR;
uut(raw := FALSE, delay := T#50ms);
ASSERT_FALSE(uut.out);
END_TEST
