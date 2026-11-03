TEST hidden_stays_until_ack
VAR uut : FB_Alarm; END_VAR
uut(condition := TRUE);
uut(condition := FALSE);
ASSERT_TRUE(uut.active);
uut(ack := TRUE);
ASSERT_FALSE(uut.active);
ASSERT_FALSE(uut.unacked);
END_TEST

TEST hidden_ack_while_present
VAR uut : FB_Alarm; END_VAR
uut(condition := TRUE);
uut(condition := TRUE, ack := TRUE);
ASSERT_TRUE(uut.active);
ASSERT_FALSE(uut.unacked);
uut(condition := FALSE, ack := FALSE);
ASSERT_FALSE(uut.active);
END_TEST

TEST hidden_new_alarm_after_clear
VAR uut : FB_Alarm; END_VAR
uut(condition := TRUE);
uut(condition := FALSE, ack := TRUE);
uut(ack := FALSE);
ASSERT_FALSE(uut.active);
uut(condition := TRUE);
ASSERT_TRUE(uut.active AND uut.unacked);
END_TEST
