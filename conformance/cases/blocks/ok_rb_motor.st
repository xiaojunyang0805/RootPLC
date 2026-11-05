(* spec: [blocks.command] [blocks.mode] [blocks.interlock] [blocks.fault] [blocks.feedback] [blocks.status]
   expect: ok
   libraries: RootBlocks *)
(* Test suite of RB_Motor (card blocks/cards/F04.MOTOR.DOL.md). Every call
   passes the inputs that matter: block inputs keep their last value. *)
TEST motor_starts_and_reports
VAR m : RB_Motor; END_VAR
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE);
ASSERT_TRUE(m.Run);
ASSERT_FALSE(m.Running);
ASSERT_TRUE(m.Status.Commanded);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE);
ASSERT_TRUE(m.Running);
ASSERT_TRUE(m.Status.Active);
ASSERT_EQ(UDINT#1, m.Status.Starts);
ASSERT_TRUE(m.Status.Mode = RB_MODE#Auto);
m(Mode := RB_MODE#Auto, AutoRun := FALSE, FbRunning := TRUE);
ASSERT_FALSE(m.Run);
m(Mode := RB_MODE#Auto, AutoRun := FALSE, FbRunning := FALSE);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE);
ASSERT_EQ(UDINT#2, m.Status.Starts);
ASSERT_FALSE(m.Error);
ASSERT_FALSE(m.Status.Error);
END_TEST

TEST motor_mode_interlock_permissive
VAR m : RB_Motor; END_VAR
m(Mode := RB_MODE#Auto, ManRun := TRUE, FbRunning := FALSE);
ASSERT_FALSE(m.Run);
m(Mode := RB_MODE#Manual, ManRun := TRUE, AutoRun := FALSE, FbRunning := FALSE);
ASSERT_TRUE(m.Run);
m(Mode := RB_MODE#Manual, ManRun := TRUE, Interlock := TRUE, FbRunning := TRUE);
ASSERT_FALSE(m.Run);
m(Mode := RB_MODE#Off, ManRun := TRUE, AutoRun := TRUE, Interlock := FALSE, FbRunning := FALSE);
ASSERT_FALSE(m.Run);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, Permissive := FALSE, FbRunning := FALSE);
ASSERT_FALSE(m.Run);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, Permissive := TRUE, FbRunning := FALSE);
ASSERT_TRUE(m.Run);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, Permissive := FALSE, FbRunning := TRUE);
ASSERT_TRUE(m.Run);
END_TEST

TEST motor_overload_trips_at_once_and_latches
VAR m : RB_Motor; END_VAR
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, Overload := TRUE);
ASSERT_FALSE(m.Run);
ASSERT_TRUE(m.Error);
ASSERT_EQ(UDINT#3, m.ErrorID);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, Overload := FALSE);
ASSERT_TRUE(m.Error);
ASSERT_FALSE(m.Run);
(* reset while still tripped: the fault returns at once *)
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, Overload := TRUE, Reset := TRUE);
ASSERT_TRUE(m.Error);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, Overload := FALSE, Reset := FALSE);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, Overload := FALSE, Reset := TRUE);
ASSERT_FALSE(m.Error);
ASSERT_EQ(UDINT#0, m.ErrorID);
ASSERT_TRUE(m.Run);
END_TEST

TEST motor_no_running_feedback
VAR m : RB_Motor; END_VAR
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, FeedbackTime := T#1s);
ADVANCE(T#900ms);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, FeedbackTime := T#1s);
ASSERT_FALSE(m.Error);
ADVANCE(T#200ms);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, FeedbackTime := T#1s);
ASSERT_TRUE(m.Error);
ASSERT_EQ(UDINT#1, m.ErrorID);
ASSERT_FALSE(m.Run);
ASSERT_EQ(UDINT#1, m.Status.ErrorID);
END_TEST

TEST motor_contactor_stuck
VAR m : RB_Motor; END_VAR
m(Mode := RB_MODE#Auto, AutoRun := FALSE, FbRunning := TRUE, FeedbackTime := T#1s);
ADVANCE(T#1100ms);
m(Mode := RB_MODE#Auto, AutoRun := FALSE, FbRunning := TRUE, FeedbackTime := T#1s);
ASSERT_TRUE(m.Error);
ASSERT_EQ(UDINT#2, m.ErrorID);
END_TEST

TEST motor_restart_delay
VAR m : RB_Motor; END_VAR
m(Mode := RB_MODE#Auto, AutoRun := FALSE, FbRunning := FALSE, RestartDelay := T#10s);
ADVANCE(T#11s);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, RestartDelay := T#10s);
ASSERT_TRUE(m.Run);
m(Mode := RB_MODE#Auto, AutoRun := FALSE, FbRunning := TRUE, RestartDelay := T#10s);
ADVANCE(T#5s);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, RestartDelay := T#10s);
ASSERT_FALSE(m.Run);
ASSERT_EQ(UDINT#1, m.Status.Starts);
ADVANCE(T#6s);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, RestartDelay := T#10s);
ASSERT_TRUE(m.Run);
ASSERT_EQ(UDINT#2, m.Status.Starts);
END_TEST

TEST motor_without_feedback
VAR m : RB_Motor; END_VAR
m(Mode := RB_MODE#Auto, AutoRun := TRUE, Feedback := FALSE, FbRunning := FALSE, FeedbackTime := T#1s);
ASSERT_TRUE(m.Running);
ADVANCE(T#5s);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, Feedback := FALSE, FbRunning := FALSE, FeedbackTime := T#1s);
ASSERT_FALSE(m.Error);
(* switching supervision on starts its timer fresh *)
m(Mode := RB_MODE#Auto, AutoRun := TRUE, Feedback := TRUE, FbRunning := FALSE, FeedbackTime := T#1s);
ASSERT_FALSE(m.Error);
ASSERT_FALSE(m.Running);
END_TEST

TEST motor_runs_normally_past_the_feedback_time
VAR m : RB_Motor; END_VAR
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, FeedbackTime := T#1s);
ADVANCE(T#3s);
m(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, FeedbackTime := T#1s);
ASSERT_FALSE(m.Error);
ASSERT_TRUE(m.Run);
END_TEST
