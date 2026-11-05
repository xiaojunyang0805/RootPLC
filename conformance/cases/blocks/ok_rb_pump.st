(* spec: [blocks.command] [blocks.interlock] [blocks.fault] [blocks.status]
   expect: ok
   libraries: RootBlocks *)
(* Test suite of RB_Pump (card blocks/cards/F04.PUMP.md). Every call passes
   the inputs that matter: block inputs keep their last value. *)
TEST pump_runs_like_a_motor
VAR p : RB_Pump; END_VAR
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE);
ASSERT_TRUE(p.Run);
ASSERT_FALSE(p.Running);
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE);
ASSERT_TRUE(p.Running);
ASSERT_EQ(UDINT#1, p.Status.Starts);
ASSERT_TRUE(p.Status.Commanded);
ASSERT_FALSE(p.Error);
p(Mode := RB_MODE#Manual, ManRun := FALSE, AutoRun := TRUE, FbRunning := TRUE);
ASSERT_FALSE(p.Run);
p(Mode := RB_MODE#Manual, ManRun := TRUE, Permissive := FALSE, FbRunning := FALSE);
ASSERT_FALSE(p.Run);
p(Mode := RB_MODE#Manual, ManRun := TRUE, Permissive := TRUE, Interlock := TRUE, FbRunning := FALSE);
ASSERT_FALSE(p.Run);
END_TEST

TEST pump_dry_run_trips_after_its_time
VAR p : RB_Pump; END_VAR
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, DryRun := FALSE, DryRunTime := T#5s);
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, DryRun := TRUE, DryRunTime := T#5s);
ADVANCE(T#4900ms);
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, DryRun := TRUE, DryRunTime := T#5s);
ASSERT_FALSE(p.Error);
ASSERT_TRUE(p.Run);
ADVANCE(T#200ms);
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, DryRun := TRUE, DryRunTime := T#5s);
ASSERT_TRUE(p.Error);
ASSERT_EQ(UDINT#4, p.ErrorID);
ASSERT_FALSE(p.Run);
ASSERT_TRUE(p.Status.Error);
ASSERT_EQ(UDINT#4, p.Status.ErrorID);
(* liquid back: still latched until reset *)
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, DryRun := FALSE, DryRunTime := T#5s);
ASSERT_TRUE(p.Error);
ASSERT_FALSE(p.Run);
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, DryRun := FALSE, DryRunTime := T#5s, Reset := TRUE);
ASSERT_FALSE(p.Error);
ASSERT_EQ(UDINT#0, p.ErrorID);
ASSERT_TRUE(p.Run);
END_TEST

TEST pump_dry_signal_while_stopped_is_no_fault
VAR p : RB_Pump; END_VAR
p(Mode := RB_MODE#Auto, AutoRun := FALSE, FbRunning := FALSE, DryRun := TRUE, DryRunTime := T#1s);
ADVANCE(T#5s);
p(Mode := RB_MODE#Auto, AutoRun := FALSE, FbRunning := FALSE, DryRun := TRUE, DryRunTime := T#1s);
ASSERT_FALSE(p.Error);
END_TEST

TEST pump_motor_faults_pass_through
VAR p : RB_Pump; q : RB_Pump; END_VAR
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, Overload := TRUE);
ASSERT_TRUE(p.Error);
ASSERT_EQ(UDINT#3, p.ErrorID);
q(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, FeedbackTime := T#1s, Feedback := TRUE);
ADVANCE(T#1100ms);
q(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, FeedbackTime := T#1s, Feedback := TRUE);
ASSERT_EQ(UDINT#1, q.ErrorID);
ASSERT_TRUE(q.Error);
END_TEST

TEST pump_motor_fault_during_dry_running_wins
VAR p : RB_Pump; END_VAR
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, DryRun := TRUE, DryRunTime := T#2s);
ADVANCE(T#1s);
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := TRUE, DryRun := TRUE, Overload := TRUE, DryRunTime := T#2s);
ASSERT_EQ(UDINT#3, p.ErrorID);
ADVANCE(T#2s);
p(Mode := RB_MODE#Auto, AutoRun := TRUE, FbRunning := FALSE, DryRun := TRUE, Overload := TRUE, DryRunTime := T#2s);
ASSERT_EQ(UDINT#3, p.ErrorID);
END_TEST
