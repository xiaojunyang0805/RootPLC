TEST visible_alarm_raises
VAR uut : FB_Alarm; END_VAR
uut(condition := TRUE);
ASSERT_TRUE(uut.active);
ASSERT_TRUE(uut.unacked);
END_TEST
