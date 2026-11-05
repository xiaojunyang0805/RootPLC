TEST visible_raise_and_count
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := TRUE, rNowS := 12.5, stAlarm := a);
ASSERT_TRUE(uut.xNewAlarm);
ASSERT_TRUE(a.xActive);
ASSERT_TRUE(a.xLatched);
ASSERT_EQ(1, a.iCount);
END_TEST
