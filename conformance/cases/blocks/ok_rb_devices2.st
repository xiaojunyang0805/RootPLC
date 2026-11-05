(* spec: [blocks.mode] [blocks.interlock] [blocks.fault] [blocks.feedback] [blocks.status] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_ValveAnalog (F04.VALVE.ANALOG), RB_MotorStarDelta
   (F04.MOTOR.STARDELTA) and RB_Diverter (F12.DIVERTER). Every call passes
   the inputs that matter: block inputs keep their last value. *)
TEST valve_analog_modes_and_limits
VAR v : RB_ValveAnalog; END_VAR
v(Mode := RB_MODE#Off, AutoPos := 40.0, ManPos := 70.0, Feedback := FALSE);
ASSERT_TRUE(ABS(v.Out) < 0.001);
ASSERT_FALSE(v.Status.Commanded);
v(Mode := RB_MODE#Auto);
ASSERT_TRUE(ABS(v.Out - 40.0) < 0.001);
ASSERT_TRUE(ABS(v.Pos - 40.0) < 0.001);
ASSERT_TRUE(v.Status.Commanded);
ASSERT_TRUE(v.Status.Active);
ASSERT_EQ(UDINT#1, v.Status.Starts);
v(Mode := RB_MODE#Manual);
ASSERT_TRUE(ABS(v.Out - 70.0) < 0.001);
ASSERT_EQ(UDINT#1, v.Status.Starts);
ASSERT_TRUE(v.Status.Mode = RB_MODE#Manual);
v(ManPos := 120.0);
ASSERT_TRUE(ABS(v.Out - 100.0) < 0.001);
v(ManPos := -5.0);
ASSERT_TRUE(ABS(v.Out) < 0.001);
ASSERT_FALSE(v.Status.Active);
v(ManPos := 3.0);
ASSERT_EQ(UDINT#2, v.Status.Starts);
(* a small opening is not reported as open (below Tolerance) *)
ASSERT_FALSE(v.Status.Active);
v(ManPos := 5.0);
ASSERT_FALSE(v.Status.Active);
v(ManPos := 6.0);
ASSERT_TRUE(v.Status.Active);
END_TEST

TEST valve_analog_interlock_goes_to_the_safe_position
VAR v : RB_ValveAnalog; END_VAR
v(Mode := RB_MODE#Auto, AutoPos := 40.0, Feedback := FALSE);
v(Interlock := TRUE);
ASSERT_TRUE(ABS(v.Out) < 0.001);
(* a valve that must open on a fault *)
v(SafePos := 100.0);
ASSERT_TRUE(ABS(v.Out - 100.0) < 0.001);
v(Interlock := FALSE);
ASSERT_TRUE(ABS(v.Out - 40.0) < 0.001);
v(Mode := RB_MODE#Off);
ASSERT_TRUE(ABS(v.Out - 100.0) < 0.001);
END_TEST

TEST valve_analog_deviation_fault
VAR v : RB_ValveAnalog; END_VAR
v(Mode := RB_MODE#Auto, AutoPos := 50.0, PosFb := 0.0, FeedbackTime := T#2s);
ASSERT_TRUE(ABS(v.Pos) < 0.001);
ADVANCE(T#1900ms);
v(PosFb := 30.0);
ASSERT_FALSE(v.Error);
ASSERT_TRUE(ABS(v.Pos - 30.0) < 0.001);
(* within tolerance: the timer restarts *)
v(PosFb := 45.0);
ADVANCE(T#5s);
v(PosFb := 45.0);
ASSERT_FALSE(v.Error);
v(PosFb := 44.0);
ADVANCE(T#1900ms);
v(PosFb := 44.0);
ASSERT_FALSE(v.Error);
ADVANCE(T#200ms);
v(PosFb := 44.0);
ASSERT_TRUE(v.Error);
ASSERT_EQ(UDINT#1, v.ErrorID);
ASSERT_TRUE(ABS(v.Out) < 0.001);
ASSERT_TRUE(v.Status.Error);
ASSERT_EQ(UDINT#1, v.Status.ErrorID);
(* the fault holds the safe position until reset *)
v(PosFb := 0.0);
ASSERT_TRUE(ABS(v.Out) < 0.001);
v(PosFb := 0.0, Reset := TRUE);
ASSERT_FALSE(v.Error);
ASSERT_EQ(UDINT#0, v.ErrorID);
ASSERT_TRUE(ABS(v.Out - 50.0) < 0.001);
END_TEST

TEST valve_analog_feedback_out_of_range
VAR v : RB_ValveAnalog; END_VAR
v(Mode := RB_MODE#Auto, AutoPos := 50.0, PosFb := 110.0);
ASSERT_FALSE(v.Error);
v(PosFb := 111.0);
ASSERT_TRUE(v.Error);
ASSERT_EQ(UDINT#2, v.ErrorID);
v(PosFb := 50.0, Reset := TRUE);
ASSERT_FALSE(v.Error);
v(PosFb := -10.0, Reset := FALSE);
ASSERT_FALSE(v.Error);
v(PosFb := -11.0);
ASSERT_TRUE(v.Error);
ASSERT_EQ(UDINT#2, v.ErrorID);
(* without feedback the signal is ignored *)
v(PosFb := -50.0, Reset := TRUE, Feedback := FALSE);
ASSERT_FALSE(v.Error);
ADVANCE(T#20s);
v(PosFb := -50.0, Reset := FALSE);
ASSERT_FALSE(v.Error);
ASSERT_TRUE(ABS(v.Pos - 50.0) < 0.001);
(* switching supervision back on starts the timer fresh *)
v(PosFb := 0.0, Feedback := TRUE);
ADVANCE(T#9s);
v(PosFb := 0.0, Feedback := FALSE);
v(PosFb := 0.0, Feedback := TRUE);
ADVANCE(T#2s);
v(PosFb := 0.0);
ASSERT_FALSE(v.Error);
END_TEST

TEST star_delta_starts_in_star_then_delta
VAR m : RB_MotorStarDelta; END_VAR
m(Mode := RB_MODE#Auto, AutoRun := FALSE);
ASSERT_FALSE(m.Main OR m.Star OR m.Delta);
m(AutoRun := TRUE, FbRunning := FALSE);
ASSERT_TRUE(m.Main);
ASSERT_TRUE(m.Star);
ASSERT_FALSE(m.Delta);
ASSERT_FALSE(m.Running);
ASSERT_EQ(UDINT#1, m.Status.Starts);
ADVANCE(T#4900ms);
m(FbRunning := TRUE);
ASSERT_TRUE(m.Star);
ASSERT_TRUE(m.Running);
ASSERT_FALSE(m.InDelta);
(* star off, a short gap with both off, then delta *)
ADVANCE(T#100ms);
m();
ASSERT_TRUE(m.Main);
ASSERT_FALSE(m.Star);
ASSERT_FALSE(m.Delta);
ADVANCE(T#40ms);
m();
ASSERT_FALSE(m.Delta);
ADVANCE(T#10ms);
m();
ASSERT_TRUE(m.Delta);
ASSERT_TRUE(m.InDelta);
ASSERT_FALSE(m.Star);
ADVANCE(T#10s);
m();
ASSERT_TRUE(m.Delta);
(* stop and start again: star first *)
m(AutoRun := FALSE, FbRunning := TRUE);
ASSERT_FALSE(m.Main OR m.Star OR m.Delta);
m(AutoRun := TRUE);
ASSERT_TRUE(m.Star);
ASSERT_FALSE(m.Delta);
ASSERT_EQ(UDINT#2, m.Status.Starts);
END_TEST

TEST star_delta_faults_and_settings
VAR m : RB_MotorStarDelta; END_VAR
m(Mode := RB_MODE#Manual, ManRun := TRUE, FbRunning := TRUE, StarTime := T#2s, Changeover := T#100ms);
ASSERT_TRUE(m.Star);
ADVANCE(T#2s);
m();
ASSERT_FALSE(m.Star);
ADVANCE(T#100ms);
m();
ASSERT_TRUE(m.Delta);
m(Overload := TRUE);
ASSERT_TRUE(m.Error);
ASSERT_EQ(UDINT#3, m.ErrorID);
ASSERT_FALSE(m.Main OR m.Star OR m.Delta);
ASSERT_TRUE(m.Status.Error);
m(Overload := FALSE, Reset := TRUE, FbRunning := FALSE);
ASSERT_FALSE(m.Error);
ASSERT_TRUE(m.Star);
(* no running feedback: fault 1 *)
ADVANCE(T#3s);
m(Reset := FALSE, FeedbackTime := T#2s);
ASSERT_TRUE(m.Error);
ASSERT_EQ(UDINT#1, m.ErrorID);
(* interlock, permissive, restart delay pass through RB_Motor *)
m(Reset := TRUE, Feedback := FALSE, Interlock := TRUE);
ASSERT_FALSE(m.Main);
m(Reset := FALSE, Interlock := FALSE, ManRun := FALSE);
m(ManRun := TRUE, Permissive := FALSE);
ASSERT_FALSE(m.Main);
m(ManRun := TRUE, Permissive := TRUE, RestartDelay := T#1s);
ASSERT_FALSE(m.Main);
ADVANCE(T#1s);
m();
ASSERT_TRUE(m.Main);
ASSERT_TRUE(m.Running);
END_TEST

TEST diverter_sends_a_part_into_the_branch
VAR d : RB_Diverter; END_VAR
d(FbStraight := TRUE);
ASSERT_FALSE(d.Gate);
ASSERT_FALSE(d.HoldPart);
(* the part arrives for the branch: hold it until the gate is over *)
d(PartAtGate := TRUE, Divert := TRUE, FbStraight := TRUE);
ASSERT_TRUE(d.Gate);
ASSERT_TRUE(d.HoldPart);
d(PartAtGate := TRUE, Divert := FALSE, FbStraight := FALSE, FbDiverted := TRUE);
ASSERT_TRUE(d.Gate);
ASSERT_FALSE(d.HoldPart);
(* it leaves the eye: counted, the gate stays for PassTime *)
d(PartAtGate := FALSE);
ASSERT_EQ(UDINT#1, d.ToBranch);
ASSERT_EQ(UDINT#0, d.ToStraight);
ADVANCE(T#900ms);
d();
ASSERT_TRUE(d.Gate);
ADVANCE(T#100ms);
d();
ASSERT_FALSE(d.Gate);
(* the gate swings back; no part is waiting, nothing to hold *)
ASSERT_FALSE(d.HoldPart);
d(FbDiverted := FALSE, FbStraight := TRUE);
ASSERT_FALSE(d.Error);
END_TEST

TEST diverter_straight_parts_and_a_quick_follower
VAR d : RB_Diverter; END_VAR
d(PartAtGate := TRUE, Divert := FALSE, FbStraight := TRUE);
ASSERT_FALSE(d.Gate);
ASSERT_FALSE(d.HoldPart);
d(PartAtGate := FALSE);
ASSERT_EQ(UDINT#1, d.ToStraight);
(* the next part, for the branch, comes during PassTime *)
ADVANCE(T#300ms);
d(PartAtGate := TRUE, Divert := TRUE);
ASSERT_TRUE(d.Gate);
ASSERT_TRUE(d.HoldPart);
ADVANCE(T#900ms);
d(FbStraight := FALSE, FbDiverted := TRUE);
ASSERT_TRUE(d.Gate);
ASSERT_FALSE(d.HoldPart);
d(PartAtGate := FALSE);
ASSERT_EQ(UDINT#1, d.ToBranch);
(* both gate switches on: not in position, the part is held *)
d(PartAtGate := FALSE);
ADVANCE(T#2s);
d(PartAtGate := FALSE, FbStraight := TRUE, FbDiverted := TRUE);
d(PartAtGate := TRUE, Divert := FALSE);
ASSERT_TRUE(d.HoldPart);
d(PartAtGate := FALSE, FbDiverted := FALSE);
ASSERT_EQ(UDINT#2, d.ToStraight);
ADVANCE(T#2s);
d();
(* a part leaving without arriving (power-up) is not counted *)
d(PartAtGate := TRUE, Divert := FALSE);
ADVANCE(T#5s);
d(PartAtGate := TRUE, FbStraight := TRUE, FbDiverted := FALSE);
d(PartAtGate := FALSE);
ASSERT_EQ(UDINT#3, d.ToStraight);
END_TEST

TEST diverter_gate_timeout
VAR d : RB_Diverter; END_VAR
d(PartAtGate := TRUE, Divert := TRUE, FbStraight := TRUE, MoveTime := T#1s);
ADVANCE(T#900ms);
d();
ASSERT_FALSE(d.Error);
ADVANCE(T#100ms);
d();
ASSERT_TRUE(d.Error);
ASSERT_EQ(UDINT#1, d.ErrorID);
ASSERT_FALSE(d.Gate);
ASSERT_TRUE(d.HoldPart);
(* the gate is straight again: reset; the part still waits, the gate retries *)
d(Reset := TRUE);
ASSERT_FALSE(d.Error);
ASSERT_EQ(UDINT#0, d.ErrorID);
ASSERT_TRUE(d.Gate);
d(Reset := FALSE, FbStraight := FALSE, FbDiverted := TRUE);
ASSERT_FALSE(d.HoldPart);
(* both switches on: not in position *)
d(FbStraight := TRUE, FbDiverted := TRUE);
ASSERT_TRUE(d.HoldPart);
END_TEST

TEST diverter_without_feedback
VAR d : RB_Diverter; END_VAR
d(Feedback := FALSE, PartAtGate := TRUE, Divert := TRUE);
ASSERT_TRUE(d.Gate);
ASSERT_FALSE(d.HoldPart);
ADVANCE(T#10s);
d();
ASSERT_FALSE(d.Error);
END_TEST
