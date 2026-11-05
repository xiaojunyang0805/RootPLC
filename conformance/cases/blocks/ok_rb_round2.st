(* spec: [blocks.mode] [blocks.interlock] [blocks.fault] [blocks.status] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_AnalogLimits (F08.LIMITS), RB_Ratio (F06.RATIO),
   RB_MotorTwoSpeed (F04.MOTOR.2SPEED), RB_Merge (F12.MERGE) and
   RB_Schedule (F03.SCHEDULE). Every call passes the inputs that matter:
   block inputs keep their last value. *)
TEST limits_with_hysteresis
VAR m : RB_AnalogLimits; END_VAR
m(Value := 50.0);
ASSERT_FALSE(m.HiHi OR m.Hi OR m.Lo OR m.LoLo OR m.Error);
m(Value := 85.0);
ASSERT_FALSE(m.Hi);
m(Value := 85.5);
ASSERT_TRUE(m.Hi);
ASSERT_FALSE(m.HiHi);
m(Value := 95.0);
ASSERT_FALSE(m.HiHi);
m(Value := 95.5);
ASSERT_TRUE(m.HiHi AND m.Hi);
(* back inside: active until Hysteresis below the limit *)
m(Value := 94.0);
ASSERT_TRUE(m.HiHi);
m(Value := 93.9);
ASSERT_FALSE(m.HiHi);
ASSERT_TRUE(m.Hi);
m(Value := 84.0);
ASSERT_TRUE(m.Hi);
m(Value := 83.9);
ASSERT_FALSE(m.Hi);
m(Value := 15.0);
ASSERT_FALSE(m.Lo);
m(Value := 14.5);
ASSERT_TRUE(m.Lo);
m(Value := 5.0);
ASSERT_FALSE(m.LoLo);
m(Value := 4.5);
ASSERT_TRUE(m.LoLo AND m.Lo);
m(Value := 6.0);
ASSERT_TRUE(m.LoLo);
m(Value := 6.1);
ASSERT_FALSE(m.LoLo);
m(Value := 16.0);
ASSERT_TRUE(m.Lo);
m(Value := 16.1);
ASSERT_FALSE(m.Lo);
END_TEST

TEST limits_enable_and_settings
VAR m : RB_AnalogLimits; END_VAR
m(Value := 99.0, EnHH := FALSE);
ASSERT_FALSE(m.HiHi);
ASSERT_TRUE(m.Hi);
m(EnH := FALSE);
ASSERT_FALSE(m.Hi);
m(Value := 1.0, EnLL := FALSE);
ASSERT_TRUE(m.Lo);
ASSERT_FALSE(m.LoLo);
m(EnL := FALSE);
ASSERT_FALSE(m.Lo);
(* limits out of order *)
m(Value := 99.0, EnHH := TRUE, EnH := TRUE, EnL := TRUE, EnLL := TRUE, H := 96.0);
ASSERT_TRUE(m.Error);
ASSERT_EQ(UDINT#1, m.ErrorID);
ASSERT_FALSE(m.HiHi OR m.Hi);
m(H := 95.0);
ASSERT_FALSE(m.Error);
ASSERT_EQ(UDINT#0, m.ErrorID);
ASSERT_TRUE(m.HiHi AND m.Hi);
m(Value := 0.0, L := 4.0);
ASSERT_TRUE(m.Error);
ASSERT_FALSE(m.Lo OR m.LoLo);
m(L := 5.0);
ASSERT_FALSE(m.Error);
ASSERT_TRUE(m.Lo AND m.LoLo);
m(L := 95.0);
ASSERT_TRUE(m.Error);
m(L := 15.0, Hysteresis := -1.0);
ASSERT_TRUE(m.Error);
m(Hysteresis := 0.0);
ASSERT_FALSE(m.Error);
END_TEST

TEST ratio_set_point
VAR r : RB_Ratio; END_VAR
r(Wild := 40.0, Ratio := 1.5, Bias := 2.0);
ASSERT_TRUE(ABS(r.SP - 62.0) < 0.001);
ASSERT_FALSE(r.Limited);
r(Wild := 80.0);
ASSERT_TRUE(ABS(r.SP - 100.0) < 0.001);
ASSERT_TRUE(r.Limited);
r(Wild := 100.0 / 1.5 - 2.0 / 1.5);
ASSERT_FALSE(r.Limited);
r(Wild := -10.0);
ASSERT_TRUE(ABS(r.SP) < 0.001);
ASSERT_TRUE(r.Limited);
r(Wild := 10.0, SPMin := 20.0);
ASSERT_TRUE(ABS(r.SP - 20.0) < 0.001);
ASSERT_TRUE(r.Limited);
ASSERT_FALSE(r.Error);
r(Wild := 12.0);
ASSERT_FALSE(r.Limited);
(* limits the wrong way round *)
r(SPMin := 60.0, SPMax := 50.0);
ASSERT_TRUE(r.Error);
ASSERT_EQ(UDINT#1, r.ErrorID);
ASSERT_TRUE(ABS(r.SP - 60.0) < 0.001);
ASSERT_TRUE(r.Limited);
r(SPMin := 50.0);
ASSERT_FALSE(r.Error);
ASSERT_EQ(UDINT#0, r.ErrorID);
END_TEST

TEST two_speed_motor_changes_speed_through_off
VAR m : RB_MotorTwoSpeed; END_VAR
m(Mode := RB_MODE#Auto, AutoRun := TRUE, AutoFast := FALSE);
ASSERT_TRUE(m.Slow);
ASSERT_FALSE(m.Fast);
ASSERT_FALSE(m.Running);
m(FbSlow := TRUE);
ASSERT_TRUE(m.Running);
ASSERT_FALSE(m.AtFast);
(* to fast: both off for Changeover first *)
m(AutoFast := TRUE, FbSlow := TRUE);
ASSERT_FALSE(m.Slow OR m.Fast);
ADVANCE(T#400ms);
m(FbSlow := FALSE);
ASSERT_FALSE(m.Slow OR m.Fast);
ADVANCE(T#100ms);
m();
ASSERT_TRUE(m.Fast);
ASSERT_FALSE(m.Slow);
ASSERT_FALSE(m.AtFast);
m(FbFast := TRUE);
ASSERT_TRUE(m.AtFast);
ASSERT_FALSE(m.Error);
ADVANCE(T#5s);
m();
ASSERT_TRUE(m.Fast);
(* back to slow, a request flipping during the gap is taken at its end *)
m(AutoFast := FALSE);
ASSERT_FALSE(m.Fast OR m.Slow);
ADVANCE(T#200ms);
m(AutoFast := TRUE, FbFast := FALSE);
ASSERT_FALSE(m.Fast OR m.Slow);
ADVANCE(T#300ms);
m();
ASSERT_TRUE(m.Fast);
(* stop; a start goes straight to the requested speed *)
m(AutoRun := FALSE);
ASSERT_FALSE(m.Fast OR m.Slow);
m(AutoRun := TRUE, AutoFast := FALSE, FbFast := FALSE, FbSlow := FALSE);
ASSERT_TRUE(m.Slow);
ASSERT_FALSE(m.Fast);
ASSERT_EQ(UDINT#2, m.Status.Starts);
END_TEST

TEST two_speed_motor_modes_and_faults
VAR m : RB_MotorTwoSpeed; END_VAR
m(Mode := RB_MODE#Manual, ManRun := TRUE, ManFast := TRUE, AutoRun := TRUE, AutoFast := FALSE);
ASSERT_TRUE(m.Fast);
m(Mode := RB_MODE#Off);
ASSERT_FALSE(m.Fast OR m.Slow);
m(Mode := RB_MODE#Auto, FbSlow := TRUE);
ASSERT_TRUE(m.Slow);
m(Overload := TRUE);
ASSERT_TRUE(m.Error);
ASSERT_EQ(UDINT#3, m.ErrorID);
ASSERT_FALSE(m.Fast OR m.Slow);
ASSERT_TRUE(m.Status.Error);
m(Overload := FALSE, Reset := TRUE);
ASSERT_FALSE(m.Error);
ASSERT_TRUE(m.Slow);
(* no feedback from either contactor *)
m(Reset := FALSE, FbSlow := FALSE, FeedbackTime := T#1s);
ADVANCE(T#1s);
m();
ASSERT_TRUE(m.Error);
ASSERT_EQ(UDINT#1, m.ErrorID);
m(Reset := TRUE, Feedback := FALSE, Interlock := TRUE);
ASSERT_FALSE(m.Slow);
m(Reset := FALSE, Interlock := FALSE, AutoRun := FALSE);
m(AutoRun := TRUE, Permissive := FALSE);
ASSERT_FALSE(m.Slow);
m(Permissive := TRUE, RestartDelay := T#1s);
ASSERT_FALSE(m.Slow);
ADVANCE(T#1s);
m();
ASSERT_TRUE(m.Slow);
ASSERT_TRUE(m.Running);
m(Changeover := T#1s, AutoFast := TRUE);
ADVANCE(T#900ms);
m();
ASSERT_FALSE(m.Fast);
ADVANCE(T#100ms);
m();
ASSERT_TRUE(m.Fast);
ASSERT_TRUE(m.AtFast);
END_TEST

TEST merge_alternates_and_counts
VAR g : RB_Merge; END_VAR
g(WaitingA := TRUE, WaitingB := TRUE, Clear := FALSE);
ASSERT_FALSE(g.ReleaseA OR g.ReleaseB);
g(Clear := TRUE);
ASSERT_TRUE(g.ReleaseA);
ASSERT_FALSE(g.ReleaseB);
(* the part passes the merge eye *)
g(MergeEye := TRUE);
ASSERT_TRUE(g.ReleaseA);
g(MergeEye := FALSE);
ASSERT_EQ(UDINT#1, g.FromA);
ASSERT_TRUE(g.ReleaseB);
ASSERT_FALSE(g.ReleaseA);
g(MergeEye := TRUE);
g(MergeEye := FALSE);
ASSERT_EQ(UDINT#1, g.FromB);
ASSERT_TRUE(g.ReleaseA);
g(MergeEye := TRUE);
g(MergeEye := FALSE, WaitingA := TRUE, WaitingB := FALSE);
ASSERT_EQ(UDINT#2, g.FromA);
(* only A waits: A again *)
ASSERT_TRUE(g.ReleaseA);
g(MergeEye := TRUE);
g(MergeEye := FALSE, WaitingA := FALSE, WaitingB := TRUE, Clear := FALSE);
ASSERT_FALSE(g.ReleaseA OR g.ReleaseB);
g(Clear := TRUE);
ASSERT_TRUE(g.ReleaseB);
(* an eye pulse with nothing released is not counted *)
g(MergeEye := TRUE);
g(MergeEye := FALSE, WaitingB := FALSE);
g(MergeEye := TRUE);
g(MergeEye := FALSE);
ASSERT_EQ(UDINT#3, g.FromA);
ASSERT_EQ(UDINT#2, g.FromB);
ASSERT_FALSE(g.ReleaseA OR g.ReleaseB);
END_TEST

TEST merge_priority_and_timeout
VAR g : RB_Merge; END_VAR
g(WaitingA := TRUE, WaitingB := TRUE, Clear := TRUE, PriorityA := TRUE, Timeout := T#2s);
ASSERT_TRUE(g.ReleaseA);
g(MergeEye := TRUE);
g(MergeEye := FALSE);
ASSERT_TRUE(g.ReleaseA);
(* nothing arrives at the eye *)
ADVANCE(T#1900ms);
g();
ASSERT_FALSE(g.Error);
ADVANCE(T#100ms);
g();
ASSERT_TRUE(g.Error);
ASSERT_EQ(UDINT#1, g.ErrorID);
ASSERT_FALSE(g.ReleaseA OR g.ReleaseB);
g(Reset := TRUE);
ASSERT_FALSE(g.Error);
ASSERT_EQ(UDINT#0, g.ErrorID);
ASSERT_TRUE(g.ReleaseA);
g(Reset := FALSE, PriorityA := FALSE);
g(MergeEye := TRUE);
g(MergeEye := FALSE);
ASSERT_TRUE(g.ReleaseB);
(* back-to-back releases: each one has its own Timeout *)
ADVANCE(T#1500ms);
g(MergeEye := TRUE);
g(MergeEye := FALSE);
ASSERT_TRUE(g.ReleaseA);
ADVANCE(T#1500ms);
g();
ASSERT_FALSE(g.Error);
ASSERT_TRUE(g.ReleaseA);
END_TEST

TEST schedule_day_window
VAR s : RB_Schedule; END_VAR
s(Now := TOD#05:59:59, Day := 1);
ASSERT_FALSE(s.Out);
s(Now := TOD#06:00:00);
ASSERT_TRUE(s.Out);
s(Now := TOD#21:59:59);
ASSERT_TRUE(s.Out);
s(Now := TOD#22:00:00);
ASSERT_FALSE(s.Out);
(* weekdays only *)
s(Now := TOD#12:00:00, Day := 6, Days := BYTE#16#1F);
ASSERT_FALSE(s.Out);
s(Day := 5);
ASSERT_TRUE(s.Out);
s(Day := 7, Days := BYTE#16#40);
ASSERT_TRUE(s.Out);
s(Enable := FALSE);
ASSERT_FALSE(s.Out);
s(Enable := TRUE, OnTime := TOD#12:00:00, OffTime := TOD#12:00:00);
ASSERT_FALSE(s.Out);
END_TEST

TEST schedule_overnight_and_errors
VAR s : RB_Schedule; END_VAR
(* a night shift Monday 22:00 to Tuesday 06:00, Mondays only *)
s(OnTime := TOD#22:00:00, OffTime := TOD#06:00:00, Days := BYTE#16#01, Now := TOD#21:00:00, Day := 1);
ASSERT_FALSE(s.Out);
s(Now := TOD#22:00:00);
ASSERT_TRUE(s.Out);
s(Now := TOD#05:00:00, Day := 2);
ASSERT_TRUE(s.Out);
s(Now := TOD#06:00:00);
ASSERT_FALSE(s.Out);
s(Now := TOD#23:00:00);
ASSERT_FALSE(s.Out);
s(Now := TOD#05:00:00, Day := 1);
ASSERT_FALSE(s.Out);
(* every day: the window ends exactly at OffTime *)
s(Days := BYTE#16#7F, Now := TOD#06:00:00, Day := 3);
ASSERT_FALSE(s.Out);
s(Now := TOD#21:59:59);
ASSERT_FALSE(s.Out);
(* Sunday night into Monday *)
s(Days := BYTE#16#40, Now := TOD#01:00:00, Day := 1);
ASSERT_TRUE(s.Out);
s(Day := 0);
ASSERT_TRUE(s.Error);
ASSERT_EQ(UDINT#1, s.ErrorID);
ASSERT_FALSE(s.Out);
s(Day := 8);
ASSERT_TRUE(s.Error);
s(Day := 7, Now := TOD#23:00:00);
ASSERT_FALSE(s.Error);
ASSERT_EQ(UDINT#0, s.ErrorID);
ASSERT_TRUE(s.Out);
END_TEST
