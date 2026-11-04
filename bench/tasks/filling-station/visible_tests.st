TEST visible_one_bottle
VAR uut : FB_Filling; i : INT; END_VAR
uut(start := TRUE);
ASSERT_EQ(1, uut.state);
ASSERT_TRUE(uut.conveyor);
uut(start := FALSE, bottle_present := TRUE);
ASSERT_EQ(2, uut.state);
ASSERT_TRUE(uut.clamp);
ASSERT_FALSE(uut.conveyor);
FOR i := 1 TO 6 DO
    ADVANCE(T#100ms);
    uut();
END_FOR;
ASSERT_EQ(3, uut.state);
ASSERT_TRUE(uut.valve);
uut(level_full := TRUE);
ASSERT_EQ(4, uut.state);
uut(cap_done := TRUE);
ASSERT_EQ(5, uut.state);
ASSERT_FALSE(uut.clamp);
uut(bottle_present := FALSE, level_full := FALSE, cap_done := FALSE);
ASSERT_EQ(1, uut.state);
ASSERT_EQ(1, uut.bottles_ok);
END_TEST
