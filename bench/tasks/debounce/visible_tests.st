TEST visible_follows_after_delay
VAR uut : FB_Debounce; i : INT; END_VAR
FOR i := 1 TO 10 DO
    uut(raw := TRUE, delay := T#50ms);
    ADVANCE(T#10ms);
END_FOR
uut(raw := TRUE, delay := T#50ms);
ASSERT_TRUE(uut.out);
END_TEST
