TEST hidden_phases
VAR uut : FB_Blink; i : INT; END_VAR
FOR i := 1 TO 25 DO
    uut(enable := TRUE, period := T#1s);
    ADVANCE(T#10ms);
END_FOR;
ASSERT_TRUE(uut.out);
FOR i := 1 TO 50 DO
    uut(enable := TRUE, period := T#1s);
    ADVANCE(T#10ms);
END_FOR;
ASSERT_FALSE(uut.out);
FOR i := 1 TO 50 DO
    uut(enable := TRUE, period := T#1s);
    ADVANCE(T#10ms);
END_FOR;
ASSERT_TRUE(uut.out);
END_TEST

TEST hidden_toggle_count
VAR uut : FB_Blink; i, toggles : INT; last : BOOL; END_VAR
uut(enable := TRUE, period := T#1s);
last := uut.out;
FOR i := 1 TO 500 DO
    ADVANCE(T#10ms);
    uut(enable := TRUE, period := T#1s);
    IF uut.out <> last THEN toggles := toggles + 1; END_IF;
    last := uut.out;
END_FOR;
ASSERT_TRUE(toggles >= 9 AND toggles <= 10);
uut(enable := FALSE);
ASSERT_FALSE(uut.out);
END_TEST

TEST hidden_reenable_restarts_on
VAR uut : FB_Blink; i : INT; END_VAR
FOR i := 1 TO 75 DO
    uut(enable := TRUE, period := T#1s);
    ADVANCE(T#10ms);
END_FOR;
ASSERT_FALSE(uut.out);
uut(enable := FALSE);
ADVANCE(T#10ms);
uut(enable := TRUE, period := T#1s);
ASSERT_TRUE(uut.out);
FOR i := 1 TO 25 DO
    uut(enable := TRUE, period := T#1s);
    ADVANCE(T#10ms);
END_FOR;
ASSERT_TRUE(uut.out);
END_TEST
