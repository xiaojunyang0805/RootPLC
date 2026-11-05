(* spec: [blocks.mode] [blocks.fault] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_Cascade (F06.CASCADE), RB_DutyStandby (F04.GROUP),
   RB_Totalizer (F09.TOTAL) and RB_OEE (F09.OEE). Every call passes the
   inputs that matter: block inputs keep their last value. *)
TEST cascade_modes
VAR c : RB_Cascade; END_VAR
c(Mode := RB_MODE#Off, SP := 70.0, PV := 60.0, InnerSP := 50.0, InnerPV := 40.0,
  KpInner := 2.0, ManValue := 33.0, OutMin := 5.0);
ASSERT_TRUE(ABS(c.Out - 5.0) < 0.001);
ASSERT_FALSE(c.InCascade);
c(Mode := RB_MODE#Manual);
ASSERT_TRUE(ABS(c.Out - 33.0) < 0.001);
(* set-point tracking: the inner set point follows the inner PV *)
ASSERT_TRUE(ABS(c.InnerSPUsed - 40.0) < 0.001);
ASSERT_FALSE(c.Saturated);
(* the inner loop alone on its own set point *)
c(Mode := RB_MODE#Auto, Cascade := FALSE);
ASSERT_FALSE(c.InCascade);
ASSERT_TRUE(ABS(c.InnerSPUsed - 50.0) < 0.001);
ASSERT_TRUE(ABS(c.Out - 20.0) < 0.001);
(* cascade: the outer loop sets the inner set point *)
c(Cascade := TRUE, KpOuter := 1.5);
ASSERT_TRUE(c.InCascade);
ASSERT_TRUE(ABS(c.InnerSPUsed - 15.0) < 0.001);
ASSERT_TRUE(ABS(c.Out - 5.0) < 0.001);
ASSERT_TRUE(c.Saturated);
c(SP := 200.0);
ASSERT_TRUE(ABS(c.InnerSPUsed - 100.0) < 0.001);
c(InnerSPMax := 80.0);
ASSERT_TRUE(ABS(c.InnerSPUsed - 80.0) < 0.001);
c(SP := 0.0, InnerSPMin := 10.0);
ASSERT_TRUE(ABS(c.InnerSPUsed - 10.0) < 0.001);
ASSERT_FALSE(c.Error);
ASSERT_EQ(UDINT#0, c.ErrorID);
END_TEST

TEST cascade_switches_bumpless
VAR c : RB_Cascade; END_VAR
(* in Manual the outer loop tracks the inner PV *)
c(Mode := RB_MODE#Manual, SP := 70.0, PV := 60.0, InnerPV := 40.0, KpOuter := 1.0,
  TiOuter := T#100s, KpInner := 1.0, TiInner := T#100s, ManValue := 30.0);
ADVANCE(T#100ms);
c();
c(Mode := RB_MODE#Auto);
ASSERT_TRUE(ABS(c.InnerSPUsed - 40.0) < 0.1);
ASSERT_TRUE(ABS(c.Out - 30.0) < 0.1);
(* then the outer integral moves the inner set point up *)
ADVANCE(T#10s);
c();
ASSERT_TRUE(c.InnerSPUsed > 40.5);
ASSERT_TRUE(c.Out > 30.0);
END_TEST

TEST cascade_errors
VAR c : RB_Cascade; END_VAR
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, InnerPV := 40.0, OutMin := 100.0);
ASSERT_TRUE(c.Error);
ASSERT_EQ(UDINT#1, c.ErrorID);
ASSERT_TRUE(ABS(c.Out - 100.0) < 0.001);
c(OutMin := 0.0, Reset := TRUE);
ASSERT_FALSE(c.Error);
c(Reset := FALSE, InnerSPMin := 100.0);
ASSERT_TRUE(c.Error);
ASSERT_EQ(UDINT#11, c.ErrorID);
c(InnerSPMin := 0.0, Reset := TRUE);
ASSERT_FALSE(c.Error);
ASSERT_EQ(UDINT#0, c.ErrorID);
END_TEST

TEST duty_standby_least_hours_and_stages
VAR g : RB_DutyStandby; av : ARRAY[1..4] OF BOOL; h : ARRAY[1..4] OF REAL; k : INT; END_VAR
FOR k := 1 TO 4 DO av[k] := TRUE; END_FOR;
h[1] := 10.0; h[2] := 5.0; h[3] := 7.0; h[4] := 3.0;
g(Demand := 0, Available := av, Hours := h, StageDelay := T#5s);
ASSERT_EQ(0, g.Running);
ADVANCE(T#10s);
g(Demand := 1, Available := av, Hours := h);
ASSERT_TRUE(g.Run[4]);
ASSERT_EQ(1, g.Running);
ASSERT_FALSE(g.Shortfall);
(* the second unit waits for the stage delay, counted from the start *)
ADVANCE(T#100ms);
g(Demand := 2, Available := av, Hours := h);
ASSERT_EQ(1, g.Running);
ADVANCE(T#4800ms);
g(Demand := 2, Available := av, Hours := h);
ASSERT_EQ(1, g.Running);
ADVANCE(T#100ms);
g(Demand := 2, Available := av, Hours := h);
ASSERT_EQ(2, g.Running);
ASSERT_TRUE(g.Run[2]);
(* hours change while running: no swapping of running units *)
h[4] := 20.0;
ADVANCE(T#10s);
g(Demand := 2, Available := av, Hours := h);
ASSERT_TRUE(g.Run[4] AND g.Run[2]);
ASSERT_FALSE(g.Run[3]);
h[4] := 3.0;
(* unit 4 trips: replaced at once by the next with fewest hours *)
av[4] := FALSE;
g(Demand := 2, Available := av, Hours := h);
ASSERT_FALSE(g.Run[4]);
ASSERT_TRUE(g.Run[3]);
ASSERT_EQ(2, g.Running);
(* demand falls: the unit with the most hours stops *)
g(Demand := 1, Available := av, Hours := h);
ASSERT_FALSE(g.Run[3]);
ASSERT_TRUE(g.Run[2]);
ASSERT_EQ(1, g.Running);
g(Demand := 0, Available := av, Hours := h);
ASSERT_EQ(0, g.Running);
ASSERT_FALSE(g.Run[2]);
END_TEST

TEST duty_standby_shortfall_and_size
VAR g : RB_DutyStandby; av : ARRAY[1..4] OF BOOL; h : ARRAY[1..4] OF REAL; END_VAR
av[1] := TRUE; av[3] := TRUE;
h[1] := 2.0; h[3] := 1.0;
g(Demand := 3, Available := av, Hours := h);
ASSERT_TRUE(g.Run[3]);
ASSERT_TRUE(g.Shortfall);
g(Demand := 3, Available := av, Hours := h);
ASSERT_TRUE(g.Run[1]);
ASSERT_EQ(2, g.Running);
ASSERT_TRUE(g.Shortfall);
(* only two units fitted: unit 3 no longer counts *)
g(Demand := 3, Available := av, Hours := h, Used := 2);
ASSERT_FALSE(g.Run[3]);
ASSERT_TRUE(g.Run[1]);
ASSERT_EQ(1, g.Running);
ASSERT_TRUE(g.Shortfall);
av[2] := TRUE;
h[2] := 9.0;
g(Demand := 9, Available := av, Hours := h);
ASSERT_EQ(2, g.Running);
ASSERT_FALSE(g.Shortfall);
(* equal hours: the lowest number first *)
g(Demand := 0, Available := av, Hours := h, Used := 4);
h[1] := 1.0; h[2] := 1.0; h[3] := 1.0;
g(Demand := 1, Available := av, Hours := h);
ASSERT_TRUE(g.Run[1]);
(* equal hours: the lowest number stops first *)
g(Demand := 2, Available := av, Hours := h);
ASSERT_TRUE(g.Run[1] AND g.Run[2]);
g(Demand := 1, Available := av, Hours := h);
ASSERT_FALSE(g.Run[1]);
ASSERT_TRUE(g.Run[2]);
(* Used is limited to 1 .. 4 *)
g(Demand := 2, Available := av, Hours := h, Used := 0);
ASSERT_TRUE(g.Run[1]);
ASSERT_EQ(1, g.Running);
av[4] := TRUE;
g(Demand := 9, Available := av, Hours := h, Used := 9);
g(Demand := 9, Available := av, Hours := h, Used := 9);
g(Demand := 9, Available := av, Hours := h, Used := 9);
g(Demand := 9, Available := av, Hours := h, Used := 9);
ASSERT_EQ(4, g.Running);
END_TEST

TEST totalizer_counts_a_rate
VAR t : RB_Totalizer; END_VAR
t(Rate := 3600.0);
ASSERT_TRUE(ABS(t.Total) < 0.0001);
ADVANCE(T#1s);
t();
ASSERT_TRUE(ABS(t.Total - 1.0) < 0.0001);
ASSERT_TRUE(t.Counting);
ADVANCE(T#2s);
t(Hold := TRUE);
ASSERT_TRUE(ABS(t.Total - 1.0) < 0.0001);
ASSERT_FALSE(t.Counting);
(* the low-flow cut-off *)
ADVANCE(T#1s);
t(Hold := FALSE, LowCut := 3600.0);
ASSERT_TRUE(ABS(t.Total - 1.0) < 0.0001);
ADVANCE(T#1s);
t(Rate := 3601.0);
ASSERT_TRUE(t.Total > 1.9);
(* another time base: litres per minute *)
t(Reset := TRUE, LowCut := 0.0, Rate := 60.0, TimeBase := T#1m);
ASSERT_TRUE(ABS(t.Total) < 0.0001);
ADVANCE(T#3s);
t(Reset := FALSE);
ASSERT_TRUE(ABS(t.Total - 3.0) < 0.0001);
ADVANCE(T#1s);
t(TimeBase := T#0s);
ASSERT_FALSE(t.Counting);
ASSERT_TRUE(ABS(t.Total - 3.0) < 0.0001);
END_TEST

TEST totalizer_batch
VAR t : RB_Totalizer; END_VAR
t(Rate := 3600.0, Preset := 5.0);
ADVANCE(T#2s);
t();
ASSERT_TRUE(ABS(t.BatchTotal - 2.0) < 0.0001);
t(StartBatch := TRUE);
ASSERT_TRUE(ABS(t.BatchTotal) < 0.0001);
ASSERT_TRUE(ABS(t.Total - 2.0) < 0.0001);
ADVANCE(T#4s);
t(StartBatch := FALSE);
ASSERT_FALSE(t.BatchDone);
ADVANCE(T#1s);
t();
ASSERT_TRUE(t.BatchDone);
ASSERT_TRUE(ABS(t.BatchTotal - 5.0) < 0.0001);
t(StartBatch := TRUE);
ASSERT_FALSE(t.BatchDone);
(* without a preset the batch is never done *)
ADVANCE(T#10s);
t(StartBatch := FALSE, Preset := 0.0);
ASSERT_FALSE(t.BatchDone);
END_TEST

TEST oee_from_time_and_counts
VAR o : RB_OEE; i : INT; END_VAR
o(Planned := TRUE, Running := TRUE, IdealCycle := T#500ms);
ASSERT_TRUE(ABS(o.OEE) < 0.0001);
ASSERT_TRUE(ABS(o.Availability) < 0.0001);
FOR i := 1 TO 8 DO
    ADVANCE(T#1s);
    o(Good := i <= 6, Reject := i > 6);
    o(Good := FALSE, Reject := FALSE);
END_FOR;
FOR i := 1 TO 2 DO
    ADVANCE(T#1s);
    o(Running := FALSE);
END_FOR;
ASSERT_EQ(UDINT#6, o.GoodCount);
ASSERT_EQ(UDINT#2, o.RejectCount);
ASSERT_TRUE(ABS(o.PlannedTime - 10.0) < 0.001);
ASSERT_TRUE(ABS(o.RunTime - 8.0) < 0.001);
ASSERT_TRUE(ABS(o.Availability - 0.8) < 0.001);
ASSERT_TRUE(ABS(o.Performance - 0.5) < 0.001);
ASSERT_TRUE(ABS(o.Quality - 0.75) < 0.001);
ASSERT_TRUE(ABS(o.OEE - 0.3) < 0.001);
(* outside planned time nothing counts *)
ADVANCE(T#5s);
o(Planned := FALSE, Running := TRUE);
ASSERT_TRUE(ABS(o.PlannedTime - 10.0) < 0.001);
ASSERT_TRUE(ABS(o.RunTime - 8.0) < 0.001);
(* performance is at most 1 *)
o(IdealCycle := T#10s);
ASSERT_TRUE(ABS(o.Performance - 1.0) < 0.001);
o(Reset := TRUE);
ASSERT_EQ(UDINT#0, o.GoodCount);
ASSERT_EQ(UDINT#0, o.RejectCount);
ASSERT_TRUE(ABS(o.Performance) < 0.0001);
ASSERT_TRUE(ABS(o.Quality) < 0.0001);
ASSERT_TRUE(ABS(o.RunTime) < 0.0001);
END_TEST

TEST duty_standby_replaces_a_tripped_unit_at_once
VAR g : RB_DutyStandby; av : ARRAY[1..4] OF BOOL; h : ARRAY[1..4] OF REAL; END_VAR
av[1] := TRUE; av[2] := TRUE; av[3] := TRUE;
h[1] := 1.0; h[2] := 2.0; h[3] := 3.0;
g(Demand := 2, Available := av, Hours := h, StageDelay := T#5s, Used := 3);
ASSERT_TRUE(g.Run[1]);
ADVANCE(T#5s);
g(Demand := 2, Available := av, Hours := h);
ASSERT_TRUE(g.Run[2]);
(* one second after that start, unit 2 trips: unit 3 starts now *)
ADVANCE(T#1s);
av[2] := FALSE;
g(Demand := 2, Available := av, Hours := h);
ASSERT_FALSE(g.Run[2]);
ASSERT_TRUE(g.Run[3]);
ASSERT_EQ(2, g.Running);
END_TEST
