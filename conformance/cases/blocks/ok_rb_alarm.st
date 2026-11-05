(* spec: [blocks.testable] [blocks.library]
   expect: ok
   libraries: RootBlocks *)
(* Test suite of RB_Alarm (F08.ALARM). Every call passes the inputs that
   matter: block inputs keep their last value. *)
TEST alarm_states_with_acknowledge_while_active
VAR a : RB_Alarm; END_VAR
a(In := FALSE);
ASSERT_TRUE(a.State = RB_ALARM_STATE#Normal);
a(In := TRUE);
ASSERT_TRUE(a.Active);
ASSERT_TRUE(a.Unacked);
ASSERT_TRUE(a.State = RB_ALARM_STATE#ActiveUnack);
ASSERT_EQ(UDINT#1, a.Count);
a(In := TRUE, Ack := TRUE);
ASSERT_FALSE(a.Unacked);
ASSERT_TRUE(a.State = RB_ALARM_STATE#ActiveAcked);
a(In := TRUE, Ack := FALSE);
ASSERT_EQ(UDINT#1, a.Count);
a(In := FALSE);
ASSERT_FALSE(a.Active);
ASSERT_TRUE(a.State = RB_ALARM_STATE#Normal);
END_TEST

TEST alarm_returns_unacknowledged
VAR a : RB_Alarm; END_VAR
a(In := TRUE);
a(In := FALSE);
ASSERT_FALSE(a.Active);
ASSERT_TRUE(a.Unacked);
ASSERT_TRUE(a.State = RB_ALARM_STATE#ReturnedUnack);
a(In := FALSE, Ack := TRUE);
ASSERT_TRUE(a.State = RB_ALARM_STATE#Normal);
a(In := TRUE, Ack := TRUE);
ASSERT_TRUE(a.State = RB_ALARM_STATE#ActiveUnack);
ASSERT_EQ(UDINT#2, a.Count);
END_TEST

TEST alarm_delays
VAR a : RB_Alarm; END_VAR
a(In := TRUE, OnDelay := T#2s, OffDelay := T#1s);
ASSERT_FALSE(a.Active);
ADVANCE(T#1900ms);
a(In := TRUE, OnDelay := T#2s, OffDelay := T#1s);
ASSERT_FALSE(a.Active);
ADVANCE(T#200ms);
a(In := TRUE, OnDelay := T#2s, OffDelay := T#1s);
ASSERT_TRUE(a.Active);
a(In := FALSE, OnDelay := T#2s, OffDelay := T#1s);
ADVANCE(T#900ms);
a(In := FALSE, OnDelay := T#2s, OffDelay := T#1s);
ASSERT_TRUE(a.Active);
ADVANCE(T#200ms);
a(In := FALSE, OnDelay := T#2s, OffDelay := T#1s);
ASSERT_FALSE(a.Active);
ASSERT_TRUE(a.State = RB_ALARM_STATE#ReturnedUnack);
END_TEST

TEST alarm_out_of_service
VAR a : RB_Alarm; END_VAR
a(In := TRUE);
a(In := TRUE, Enable := FALSE);
ASSERT_FALSE(a.Active);
ASSERT_FALSE(a.Unacked);
ASSERT_TRUE(a.State = RB_ALARM_STATE#Normal);
a(In := TRUE, Enable := FALSE);
ASSERT_EQ(UDINT#1, a.Count);
a(In := TRUE, Enable := TRUE);
ASSERT_TRUE(a.Active);
ASSERT_EQ(UDINT#2, a.Count);
END_TEST
