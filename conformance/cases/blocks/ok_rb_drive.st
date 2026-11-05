(* spec: [blocks.command] [blocks.mode] [blocks.interlock] [blocks.fault] [blocks.feedback] [blocks.status]
   expect: ok
   libraries: RootBlocks *)
(* Test suite of RB_Drive (card blocks/cards/F04.DRIVE.md). Every call passes
   the inputs that matter: block inputs keep their last value. *)
TEST drive_runs_at_the_clamped_set_point
VAR d : RB_Drive; END_VAR
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 60.0, DriveReady := TRUE, DriveRunning := FALSE);
ASSERT_TRUE(d.Run);
ASSERT_TRUE(ABS(d.SpeedSetpoint - 60.0) < 0.001);
ASSERT_FALSE(d.Reverse);
ASSERT_FALSE(d.Running);
ASSERT_FALSE(d.AtSpeed);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 130.0, DriveReady := TRUE, DriveRunning := TRUE);
ASSERT_TRUE(ABS(d.SpeedSetpoint - 100.0) < 0.001);
ASSERT_TRUE(d.Running);
ASSERT_TRUE(d.AtSpeed);
ASSERT_TRUE(d.Status.Active);
ASSERT_TRUE(d.Status.Commanded);
ASSERT_EQ(UDINT#1, d.Status.Starts);
ASSERT_TRUE(d.Status.Mode = RB_MODE#Auto);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 5.0, SpeedMin := 20.0, AutoReverse := TRUE, DriveReady := TRUE, DriveRunning := TRUE);
ASSERT_TRUE(ABS(d.SpeedSetpoint - 20.0) < 0.001);
ASSERT_TRUE(d.Reverse);
ASSERT_EQ(UDINT#1, d.Status.Starts);
d(Mode := RB_MODE#Auto, AutoRun := FALSE, AutoSpeed := 50.0, AutoReverse := TRUE, DriveReady := TRUE, DriveRunning := TRUE);
ASSERT_FALSE(d.Run);
ASSERT_TRUE(ABS(d.SpeedSetpoint) < 0.001);
ASSERT_FALSE(d.Reverse);
ASSERT_FALSE(d.Error);
ASSERT_FALSE(d.Status.Error);
END_TEST

TEST drive_modes_interlock_permissive_ready
VAR d : RB_Drive; END_VAR
d(Mode := RB_MODE#Auto, ManRun := TRUE, ManSpeed := 30.0, DriveReady := TRUE);
ASSERT_FALSE(d.Run);
d(Mode := RB_MODE#Manual, ManRun := TRUE, ManSpeed := 30.0, ManReverse := TRUE, AutoRun := FALSE, DriveReady := TRUE);
ASSERT_TRUE(d.Run);
ASSERT_TRUE(ABS(d.SpeedSetpoint - 30.0) < 0.001);
ASSERT_TRUE(d.Reverse);
d(Mode := RB_MODE#Manual, ManRun := TRUE, Interlock := TRUE, DriveReady := TRUE, DriveRunning := TRUE);
ASSERT_FALSE(d.Run);
d(Mode := RB_MODE#Off, ManRun := TRUE, AutoRun := TRUE, AutoSpeed := 40.0, AutoReverse := TRUE, Interlock := FALSE, DriveReady := TRUE, DriveRunning := FALSE);
ASSERT_FALSE(d.Run);
ASSERT_FALSE(d.Reverse);
ASSERT_TRUE(ABS(d.SpeedSetpoint) < 0.001);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, Permissive := FALSE, DriveReady := TRUE, DriveRunning := FALSE);
ASSERT_FALSE(d.Run);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, Permissive := TRUE, DriveReady := FALSE, DriveRunning := FALSE);
ASSERT_FALSE(d.Run);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, Permissive := TRUE, DriveReady := TRUE, DriveRunning := FALSE);
ASSERT_TRUE(d.Run);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, Permissive := FALSE, DriveReady := FALSE, DriveRunning := TRUE);
ASSERT_TRUE(d.Run);
END_TEST

TEST drive_fault_from_the_drive_and_reset_pulse
VAR d : RB_Drive; END_VAR
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, AutoReverse := TRUE, DriveReady := TRUE, DriveRunning := TRUE);
ASSERT_TRUE(d.Reverse);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, AutoReverse := TRUE, DriveReady := FALSE, DriveRunning := FALSE, DriveFault := TRUE);
ASSERT_FALSE(d.Reverse);
ASSERT_TRUE(d.Error);
ASSERT_EQ(UDINT#3, d.ErrorID);
ASSERT_FALSE(d.Run);
ASSERT_TRUE(ABS(d.SpeedSetpoint) < 0.001);
ASSERT_FALSE(d.ResetDrive);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, DriveReady := TRUE, DriveFault := FALSE, Reset := TRUE);
ASSERT_TRUE(d.ResetDrive);
ASSERT_FALSE(d.Error);
ASSERT_EQ(UDINT#0, d.ErrorID);
ASSERT_TRUE(d.Run);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, DriveReady := TRUE, DriveRunning := TRUE, Reset := TRUE);
ASSERT_FALSE(d.ResetDrive);
END_TEST

TEST drive_run_feedback_supervision
VAR a : RB_Drive; b : RB_Drive; END_VAR
a(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := FALSE, FeedbackTime := T#1s);
ADVANCE(T#900ms);
a(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := FALSE, FeedbackTime := T#1s);
ASSERT_FALSE(a.Error);
ADVANCE(T#200ms);
a(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := FALSE, FeedbackTime := T#1s);
ASSERT_TRUE(a.Error);
ASSERT_EQ(UDINT#1, a.ErrorID);
ASSERT_EQ(UDINT#1, a.Status.ErrorID);
b(Mode := RB_MODE#Auto, AutoRun := FALSE, DriveReady := TRUE, DriveRunning := TRUE, FeedbackTime := T#1s);
ADVANCE(T#1100ms);
b(Mode := RB_MODE#Auto, AutoRun := FALSE, DriveReady := TRUE, DriveRunning := TRUE, FeedbackTime := T#1s);
ASSERT_TRUE(b.Error);
ASSERT_EQ(UDINT#2, b.ErrorID);
END_TEST

TEST drive_speed_deviation
VAR d : RB_Drive; e : RB_Drive; END_VAR
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := TRUE, ActualSpeed := 50.0, SpeedTolerance := 2.0, FeedbackTime := T#1s);
ASSERT_TRUE(d.AtSpeed);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := TRUE, ActualSpeed := 52.0, SpeedTolerance := 2.0, FeedbackTime := T#1s);
ASSERT_TRUE(d.AtSpeed);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := TRUE, ActualSpeed := 40.0, SpeedTolerance := 2.0, FeedbackTime := T#1s);
ASSERT_FALSE(d.AtSpeed);
ADVANCE(T#900ms);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := TRUE, ActualSpeed := 40.0, SpeedTolerance := 2.0, FeedbackTime := T#1s);
ASSERT_FALSE(d.Error);
ADVANCE(T#200ms);
d(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := TRUE, ActualSpeed := 40.0, SpeedTolerance := 2.0, FeedbackTime := T#1s);
ASSERT_TRUE(d.Error);
ASSERT_EQ(UDINT#4, d.ErrorID);
(* without a tolerance the speed is not supervised *)
e(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := TRUE, ActualSpeed := 10.0, SpeedTolerance := 0.0, FeedbackTime := T#1s);
ADVANCE(T#3s);
e(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoSpeed := 50.0, DriveReady := TRUE, DriveRunning := TRUE, ActualSpeed := 10.0, SpeedTolerance := 0.0, FeedbackTime := T#1s);
ASSERT_FALSE(e.Error);
ASSERT_TRUE(e.AtSpeed);
(* a running drive that is not commanded is no speed deviation *)
e(Mode := RB_MODE#Auto, AutoRun := FALSE, DriveReady := TRUE, DriveRunning := FALSE, ActualSpeed := 30.0, SpeedTolerance := 2.0, FeedbackTime := T#1s);
ADVANCE(T#3s);
e(Mode := RB_MODE#Auto, AutoRun := FALSE, DriveReady := TRUE, DriveRunning := FALSE, ActualSpeed := 30.0, SpeedTolerance := 2.0, FeedbackTime := T#1s);
ASSERT_FALSE(e.Error);
END_TEST
