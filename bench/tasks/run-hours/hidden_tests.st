TEST hidden_accumulates_across_stops
VAR uut : FB_RunHours; i : INT; END_VAR
FOR i := 1 TO 9000 DO
    uut(running := TRUE);
    ADVANCE(T#1s);
END_FOR;
uut(running := TRUE);
FOR i := 1 TO 600 DO
    uut(running := FALSE);
    ADVANCE(T#1s);
END_FOR;
FOR i := 1 TO 1800 DO
    uut(running := TRUE);
    ADVANCE(T#1s);
END_FOR;
uut(running := TRUE);
uut(running := FALSE);
ASSERT_TRUE(uut.hours = 3);
ASSERT_EQ(0, uut.minutes);
uut(reset := TRUE);
ASSERT_TRUE(uut.hours = 0);
ASSERT_EQ(0, uut.minutes);
END_TEST

TEST hidden_idle_does_not_count
VAR uut : FB_RunHours; i : INT; END_VAR
FOR i := 1 TO 3600 DO
    uut(running := FALSE);
    ADVANCE(T#1s);
END_FOR;
ASSERT_TRUE(uut.hours = 0);
ASSERT_EQ(0, uut.minutes);
END_TEST
