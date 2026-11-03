TEST hidden_within_window
VAR uut : FB_TwoHand; i : INT; END_VAR
FOR i := 1 TO 30 DO
    uut(left := TRUE, right := FALSE);
    ADVANCE(T#10ms);
END_FOR
uut(left := TRUE, right := TRUE);
ASSERT_TRUE(uut.enable);
END_TEST

TEST hidden_too_late
VAR uut : FB_TwoHand; i : INT; END_VAR
FOR i := 1 TO 70 DO
    uut(left := TRUE, right := FALSE);
    ADVANCE(T#10ms);
END_FOR
uut(left := TRUE, right := TRUE);
ASSERT_FALSE(uut.enable);
END_TEST

TEST hidden_release_and_rearm
VAR uut : FB_TwoHand; END_VAR
uut(left := TRUE, right := TRUE);
ASSERT_TRUE(uut.enable);
uut(left := TRUE, right := FALSE);
ASSERT_FALSE(uut.enable);
uut(left := TRUE, right := TRUE);
ASSERT_FALSE(uut.enable);
uut(left := FALSE, right := FALSE);
uut(left := TRUE, right := TRUE);
ASSERT_TRUE(uut.enable);
END_TEST
