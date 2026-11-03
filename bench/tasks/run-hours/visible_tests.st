TEST visible_ninety_minutes
VAR uut : FB_RunHours; i : INT; END_VAR
FOR i := 1 TO 5400 DO
    uut(running := TRUE);
    ADVANCE(T#1s);
END_FOR
uut(running := TRUE);
ASSERT_TRUE(uut.hours = 1);
ASSERT_EQ(30, uut.minutes);
END_TEST
