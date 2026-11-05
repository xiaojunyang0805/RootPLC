(* spec: [blocks.library] [blocks.command] [blocks.mode] [blocks.interlock] [blocks.fault] [blocks.feedback] [blocks.status] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suite of RB_ValveOnOff (card blocks/cards/F04.VALVE.ONOFF.md). *)
TEST valve_auto_opens_and_reports
VAR v : RB_ValveOnOff; END_VAR
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_TRUE(v.Open);
ASSERT_FALSE(v.IsOpen);
ASSERT_TRUE(v.Status.Commanded);
ASSERT_FALSE(v.Status.Active);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := TRUE, FbClosed := FALSE);
ASSERT_TRUE(v.IsOpen);
ASSERT_FALSE(v.IsClosed);
ASSERT_TRUE(v.Status.Active);
ASSERT_EQ(UDINT#1, v.Status.Starts);
ASSERT_TRUE(v.Status.Mode = RB_MODE#Auto);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := TRUE, FbClosed := FALSE);
ASSERT_EQ(UDINT#1, v.Status.Starts);
v(Mode := RB_MODE#Auto, AutoOpen := FALSE, FbOpen := TRUE, FbClosed := FALSE);
ASSERT_FALSE(v.Open);
v(Mode := RB_MODE#Auto, AutoOpen := FALSE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_TRUE(v.IsClosed);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_EQ(UDINT#2, v.Status.Starts);
ASSERT_FALSE(v.Error);
END_TEST

TEST valve_mode_selects_the_command
VAR v : RB_ValveOnOff; END_VAR
v(Mode := RB_MODE#Auto, ManOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_FALSE(v.Open);
v(Mode := RB_MODE#Manual, ManOpen := TRUE, AutoOpen := FALSE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_TRUE(v.Open);
v(Mode := RB_MODE#Manual, ManOpen := FALSE, AutoOpen := TRUE, FbOpen := TRUE, FbClosed := FALSE);
ASSERT_FALSE(v.Open);
v(Mode := RB_MODE#Off, ManOpen := TRUE, AutoOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_FALSE(v.Open);
ASSERT_TRUE(v.Status.Mode = RB_MODE#Off);
END_TEST

TEST valve_interlock_closes_in_every_mode
VAR v : RB_ValveOnOff; END_VAR
v(Mode := RB_MODE#Manual, ManOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE);
v(Mode := RB_MODE#Manual, ManOpen := TRUE, FbOpen := TRUE, FbClosed := FALSE);
ASSERT_TRUE(v.Open);
v(Mode := RB_MODE#Manual, ManOpen := TRUE, Interlock := TRUE, FbOpen := TRUE, FbClosed := FALSE);
ASSERT_FALSE(v.Open);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Interlock := TRUE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_FALSE(v.Open);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Interlock := FALSE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_TRUE(v.Open);
END_TEST

TEST valve_permissive_is_needed_to_open_not_to_stay_open
VAR v : RB_ValveOnOff; END_VAR
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Permissive := FALSE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_FALSE(v.Open);
ASSERT_EQ(UDINT#0, v.Status.Starts);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Permissive := TRUE, FbOpen := FALSE, FbClosed := TRUE);
ASSERT_TRUE(v.Open);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Permissive := FALSE, FbOpen := TRUE, FbClosed := FALSE);
ASSERT_TRUE(v.Open);
END_TEST

TEST valve_does_not_open_in_time_latches_until_reset
VAR v : RB_ValveOnOff; END_VAR
(* stuck closed: the closed switch stays on *)
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#2s);
ADVANCE(T#1900ms);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#2s);
ASSERT_FALSE(v.Error);
ADVANCE(T#200ms);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#2s);
ASSERT_TRUE(v.Error);
ASSERT_EQ(UDINT#1, v.ErrorID);
ASSERT_FALSE(v.Open);
ASSERT_TRUE(v.Status.Error);
ASSERT_EQ(UDINT#1, v.Status.ErrorID);
(* the cause goes away: the fault stays latched *)
ADVANCE(T#5s);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#2s);
ASSERT_TRUE(v.Error);
ASSERT_FALSE(v.Open);
(* reset: it opens again; still stuck, so the fault returns after 2 s *)
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#2s, Reset := TRUE);
ASSERT_FALSE(v.Error);
ASSERT_EQ(UDINT#0, v.ErrorID);
ASSERT_TRUE(v.Open);
ADVANCE(T#2100ms);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#2s, Reset := TRUE);
ASSERT_TRUE(v.Error);
ASSERT_EQ(UDINT#1, v.ErrorID);
END_TEST

TEST valve_does_not_close_in_time
VAR v : RB_ValveOnOff; END_VAR
(* stuck open: no command, the open switch stays on *)
v(Mode := RB_MODE#Auto, FbOpen := TRUE, FeedbackTime := T#1s);
ADVANCE(T#1100ms);
v(Mode := RB_MODE#Auto, FbOpen := TRUE, FeedbackTime := T#1s);
ASSERT_TRUE(v.Error);
ASSERT_EQ(UDINT#2, v.ErrorID);
END_TEST

TEST valve_contradicting_feedback
VAR v : RB_ValveOnOff; END_VAR
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := TRUE, FbClosed := TRUE, FeedbackTime := T#1s);
ADVANCE(T#900ms);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := TRUE, FbClosed := TRUE, FeedbackTime := T#1s);
ASSERT_FALSE(v.Error);
ADVANCE(T#200ms);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, FbOpen := TRUE, FbClosed := TRUE, FeedbackTime := T#1s);
ASSERT_TRUE(v.Error);
ASSERT_EQ(UDINT#3, v.ErrorID);
ASSERT_FALSE(v.IsOpen);
ASSERT_FALSE(v.IsClosed);
END_TEST

TEST valve_without_feedback_follows_the_command
VAR v : RB_ValveOnOff; END_VAR
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Feedback := FALSE, FeedbackTime := T#1s);
ASSERT_TRUE(v.IsOpen);
ASSERT_FALSE(v.IsClosed);
ADVANCE(T#5s);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Feedback := FALSE, FeedbackTime := T#1s);
ASSERT_FALSE(v.Error);
v(Mode := RB_MODE#Auto, AutoOpen := FALSE, Feedback := FALSE, FeedbackTime := T#1s);
ASSERT_FALSE(v.IsOpen);
ASSERT_TRUE(v.IsClosed);
END_TEST

TEST valve_feedback_switched_on_starts_supervision_fresh
VAR v : RB_ValveOnOff; END_VAR
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Feedback := FALSE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#1s);
ADVANCE(T#5s);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Feedback := FALSE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#1s);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Feedback := TRUE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#1s);
ASSERT_FALSE(v.Error);
ADVANCE(T#1100ms);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Feedback := TRUE, FbOpen := FALSE, FbClosed := TRUE, FeedbackTime := T#1s);
ASSERT_TRUE(v.Error);
END_TEST

TEST valve_conflict_supervision_starts_fresh_too
VAR v : RB_ValveOnOff; END_VAR
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Feedback := FALSE, FbOpen := TRUE, FbClosed := TRUE, FeedbackTime := T#1s);
ADVANCE(T#5s);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Feedback := FALSE, FbOpen := TRUE, FbClosed := TRUE, FeedbackTime := T#1s);
v(Mode := RB_MODE#Auto, AutoOpen := TRUE, Feedback := TRUE, FbOpen := TRUE, FbClosed := TRUE, FeedbackTime := T#1s);
ASSERT_FALSE(v.Error);
END_TEST
