TEST hidden_new_alarm_is_one_pulse
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := TRUE, rNowS := 1.0, iPriority := 1, stAlarm := a);
ASSERT_TRUE(uut.xNewAlarm);
ASSERT_EQ(1, a.iPriority);
ASSERT_TRUE(ABS(a.rTimeInS - 1.0) < 0.001);
ASSERT_FALSE(a.xAcked);
uut(xCondition := TRUE, rNowS := 2.0, iPriority := 1, stAlarm := a);
ASSERT_FALSE(uut.xNewAlarm);
ASSERT_EQ(1, a.iCount);
ASSERT_TRUE(ABS(a.rTimeInS - 1.0) < 0.001);
END_TEST

TEST hidden_clear_needs_ack_and_no_condition_ack_first
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := TRUE, stAlarm := a);
uut(xCondition := TRUE, xAck := TRUE, stAlarm := a);
ASSERT_TRUE(a.xAcked);
ASSERT_TRUE(a.xLatched);
uut(xCondition := FALSE, xAck := FALSE, stAlarm := a);
ASSERT_FALSE(a.xActive);
ASSERT_FALSE(a.xLatched);
END_TEST

TEST hidden_clear_needs_ack_and_no_condition_condition_first
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := TRUE, stAlarm := a);
uut(xCondition := FALSE, stAlarm := a);
ASSERT_FALSE(a.xActive);
ASSERT_TRUE(a.xLatched);
uut(xCondition := FALSE, xAck := TRUE, stAlarm := a);
ASSERT_FALSE(a.xLatched);
END_TEST

TEST hidden_ack_without_alarm_has_no_effect
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := FALSE, xAck := TRUE, stAlarm := a);
ASSERT_FALSE(a.xAcked);
uut(xCondition := TRUE, xAck := FALSE, stAlarm := a);
ASSERT_FALSE(a.xAcked);
ASSERT_TRUE(a.xLatched);
END_TEST

TEST hidden_reraise_counts_and_clears_ack
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := TRUE, rNowS := 1.0, stAlarm := a);
uut(xCondition := TRUE, xAck := TRUE, stAlarm := a);
uut(xCondition := FALSE, xAck := FALSE, stAlarm := a);
uut(xCondition := TRUE, rNowS := 9.0, stAlarm := a);
ASSERT_TRUE(uut.xNewAlarm);
ASSERT_EQ(2, a.iCount);
ASSERT_FALSE(a.xAcked);
ASSERT_TRUE(a.xLatched);
ASSERT_TRUE(ABS(a.rTimeInS - 9.0) < 0.001);
END_TEST

TEST hidden_on_delay
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := TRUE, tOnDelay := T#3s, stAlarm := a);
ASSERT_FALSE(a.xActive);
ADVANCE(T#2s);
uut(xCondition := TRUE, tOnDelay := T#3s, stAlarm := a);
ASSERT_FALSE(a.xActive);
ASSERT_FALSE(a.xLatched);
ADVANCE(T#1s);
uut(xCondition := TRUE, tOnDelay := T#3s, stAlarm := a);
ASSERT_TRUE(a.xActive);
ASSERT_TRUE(uut.xNewAlarm);
END_TEST

TEST hidden_short_condition_filtered_by_on_delay
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := TRUE, tOnDelay := T#3s, stAlarm := a);
ADVANCE(T#2s);
uut(xCondition := FALSE, tOnDelay := T#3s, stAlarm := a);
ADVANCE(T#5s);
uut(xCondition := FALSE, tOnDelay := T#3s, stAlarm := a);
ASSERT_EQ(0, a.iCount);
ASSERT_FALSE(a.xLatched);
END_TEST

TEST hidden_off_delay
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := TRUE, tOffDelay := T#2s, stAlarm := a);
uut(xCondition := FALSE, tOffDelay := T#2s, stAlarm := a);
ASSERT_TRUE(a.xActive);
ADVANCE(T#2s);
uut(xCondition := FALSE, tOffDelay := T#2s, stAlarm := a);
ASSERT_FALSE(a.xActive);
END_TEST

TEST hidden_disabled_alarm_never_raises
VAR uut : FB_Alarm; a : ST_Alarm; END_VAR
uut(xCondition := TRUE, xEnable := FALSE, stAlarm := a);
ASSERT_FALSE(a.xActive);
ASSERT_FALSE(uut.xNewAlarm);
ASSERT_EQ(0, a.iCount);
END_TEST
