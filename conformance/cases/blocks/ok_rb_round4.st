(* spec: [blocks.fault] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_SetpointProfile (F06.PROFILE), RB_Homing (F05.HOMING),
   RB_DataLog (F11.LOG), RB_ScaleOut (F01.SCALE.OUT) and RB_Drum
   (F05.DRUM). Every call passes the inputs that matter: block inputs keep
   their last value. *)
FUNCTION_BLOCK FB_Profile2
VAR_OUTPUT
    tg : ARRAY[1..8] OF REAL;
    rt : ARRAY[1..8] OF TIME;
    st : ARRAY[1..8] OF TIME;
END_VAR
tg[1] := 100.0; rt[1] := T#10s; st[1] := T#5s;
tg[2] := 50.0;  rt[2] := T#5s;  st[2] := T#2s;
END_FUNCTION_BLOCK

TEST profile_ramps_and_soaks
VAR p : RB_SetpointProfile; d : FB_Profile2; END_VAR
d();
p(PV := 20.0, Count := 2, Targets := d.tg, RampTimes := d.rt, SoakTimes := d.st);
ASSERT_FALSE(p.Busy);
ASSERT_EQ(0, p.Segment);
ADVANCE(T#1s);
p(Start := TRUE);
ASSERT_TRUE(p.Busy);
ASSERT_EQ(1, p.Segment);
ASSERT_TRUE(ABS(p.SP - 20.0) < 0.001);
ADVANCE(T#5s);
p(Start := FALSE);
ASSERT_TRUE(ABS(p.SP - 60.0) < 0.01);
ASSERT_FALSE(p.Soaking);
ADVANCE(T#5s);
p();
ASSERT_TRUE(ABS(p.SP - 100.0) < 0.001);
ASSERT_TRUE(p.Soaking);
ADVANCE(T#4900ms);
p();
ASSERT_EQ(1, p.Segment);
ADVANCE(T#100ms);
p();
ASSERT_EQ(2, p.Segment);
ASSERT_FALSE(p.Soaking);
ADVANCE(T#2500ms);
p();
ASSERT_TRUE(ABS(p.SP - 75.0) < 0.01);
ADVANCE(T#2500ms);
p();
ASSERT_TRUE(ABS(p.SP - 50.0) < 0.001);
ADVANCE(T#2s);
p();
ASSERT_TRUE(p.Done);
ASSERT_FALSE(p.Busy);
ASSERT_EQ(0, p.Segment);
ASSERT_TRUE(ABS(p.SP - 50.0) < 0.001);
(* a new start clears Done *)
p(Start := TRUE, PV := 30.0);
ASSERT_FALSE(p.Done);
ASSERT_TRUE(ABS(p.SP - 30.0) < 0.001);
END_TEST

TEST profile_hold_guarantee_and_abort
VAR p : RB_SetpointProfile; d : FB_Profile2; END_VAR
d();
p(PV := 20.0, Count := 1, Targets := d.tg, RampTimes := d.rt, SoakTimes := d.st, Start := TRUE);
ADVANCE(T#5s);
p(Start := FALSE);
ASSERT_TRUE(ABS(p.SP - 60.0) < 0.01);
ADVANCE(T#10s);
p(Hold := TRUE);
ASSERT_TRUE(ABS(p.SP - 60.0) < 0.01);
p(Hold := FALSE);
ADVANCE(T#5s);
p(Band := 2.0);
ASSERT_TRUE(p.Soaking);
(* guaranteed soak: PV far from SP, the soak waits *)
ADVANCE(T#10s);
p(PV := 90.0);
ASSERT_TRUE(p.Soaking);
ASSERT_EQ(1, p.Segment);
ADVANCE(T#1s);
p(PV := 98.0);
(* each call counts the time since the previous one *)
ADVANCE(T#3s);
p(PV := 98.0);
ASSERT_TRUE(p.Busy);
ADVANCE(T#1s);
p(PV := 98.0);
ASSERT_TRUE(p.Done);
(* abort while soaking *)
p(Start := TRUE, PV := 100.0);
ASSERT_TRUE(p.Busy);
ADVANCE(T#10s);
p(Start := FALSE);
ASSERT_TRUE(p.Soaking);
p(Abort := TRUE);
ASSERT_FALSE(p.Soaking);
ASSERT_FALSE(p.Busy);
ASSERT_EQ(0, p.Segment);
ASSERT_FALSE(p.Done);
ADVANCE(T#20s);
p(Abort := FALSE);
ASSERT_FALSE(p.Busy);
END_TEST

TEST profile_zero_times_and_count
VAR p : RB_SetpointProfile; tg : ARRAY[1..8] OF REAL; rt, st : ARRAY[1..8] OF TIME; END_VAR
tg[1] := 70.0;
p(PV := 10.0, Count := 0, Targets := tg, RampTimes := rt, SoakTimes := st, Start := TRUE);
ASSERT_TRUE(p.Error);
ASSERT_EQ(UDINT#1, p.ErrorID);
ASSERT_FALSE(p.Busy);
p(Start := FALSE, Count := 9);
p(Start := TRUE);
ASSERT_TRUE(p.Error);
p(Start := FALSE, Count := 8);
p(Start := TRUE);
ASSERT_FALSE(p.Error);
ASSERT_EQ(UDINT#0, p.ErrorID);
(* T#0s ramp and soak: a step to the target, one segment per call *)
p(Start := FALSE);
ASSERT_TRUE(ABS(p.SP - 70.0) < 0.001);
p();
ASSERT_EQ(2, p.Segment);
p(Count := 1);
p();
ASSERT_TRUE(p.Done);
(* a start with a bad count while running ends the program *)
p(Count := 8);
p(Start := TRUE);
p(Start := FALSE);
p();
ASSERT_EQ(2, p.Segment);
p(Count := 0);
p(Start := TRUE);
ASSERT_EQ(0, p.Segment);
ASSERT_FALSE(p.Busy);
END_TEST

TEST homing_seeks_and_backs_off
VAR h : RB_Homing; END_VAR
h();
ASSERT_FALSE(h.Busy OR h.Homed);
h(Start := TRUE);
ASSERT_TRUE(h.MoveToHome);
ASSERT_FALSE(h.MoveAway OR h.Slow);
ASSERT_TRUE(h.Busy);
ADVANCE(T#20s);
h(Start := FALSE, HomeSwitch := TRUE);
ASSERT_FALSE(h.MoveToHome);
ASSERT_TRUE(h.MoveAway AND h.Slow);
(* each phase has its own Timeout *)
ADVANCE(T#20s);
h();
ASSERT_FALSE(h.Error);
h(HomeSwitch := FALSE);
ASSERT_TRUE(h.Homed);
ASSERT_FALSE(h.Busy OR h.MoveAway OR h.MoveToHome);
(* starting on the switch: straight to backing off; Homed clears *)
h(Start := TRUE, HomeSwitch := TRUE);
ASSERT_FALSE(h.Homed);
ASSERT_TRUE(h.MoveAway);
h(Start := FALSE, HomeSwitch := FALSE);
ASSERT_TRUE(h.Homed);
(* a new start while seeking restarts the timing *)
h(Start := TRUE, Timeout := T#2s);
ADVANCE(T#1500ms);
h(Start := FALSE);
h(Start := TRUE);
ADVANCE(T#1500ms);
h(Start := FALSE);
ASSERT_FALSE(h.Error);
ASSERT_TRUE(h.MoveToHome);
h(Timeout := T#30s);
(* abort *)
h(Start := TRUE);
ASSERT_TRUE(h.MoveToHome);
h(Start := FALSE, Abort := TRUE);
ASSERT_FALSE(h.Busy OR h.MoveToHome OR h.Homed);
h(Start := TRUE);
ASSERT_FALSE(h.Busy);
END_TEST

TEST homing_timeouts
VAR h : RB_Homing; END_VAR
h(Start := TRUE, Timeout := T#2s);
ADVANCE(T#1900ms);
h();
ASSERT_FALSE(h.Error);
ADVANCE(T#100ms);
h();
ASSERT_TRUE(h.Error);
ASSERT_EQ(UDINT#1, h.ErrorID);
ASSERT_FALSE(h.MoveToHome OR h.Busy);
(* no start while the fault lasts *)
h(Start := FALSE);
h(Start := TRUE);
ASSERT_FALSE(h.Busy);
h(Start := FALSE, Reset := TRUE);
ASSERT_FALSE(h.Error);
ASSERT_EQ(UDINT#0, h.ErrorID);
h(Reset := FALSE, Start := TRUE);
ASSERT_TRUE(h.MoveToHome);
h(Start := FALSE, HomeSwitch := TRUE);
ADVANCE(T#2s);
h();
ASSERT_TRUE(h.Error);
ASSERT_EQ(UDINT#2, h.ErrorID);
ASSERT_FALSE(h.MoveAway OR h.Slow);
ASSERT_FALSE(h.Homed);
END_TEST

TEST data_log_ring_and_statistics
VAR l : RB_DataLog; i : INT; END_VAR
l(Value := 0.0, Enable := FALSE);
ASSERT_EQ(0, l.Count);
ASSERT_EQ(0, l.Newest);
l(Value := 5.0, Enable := TRUE);
ASSERT_EQ(1, l.Count);
ASSERT_EQ(1, l.Newest);
ASSERT_TRUE(ABS(l.Minimum - 5.0) < 0.001 AND ABS(l.Maximum - 5.0) < 0.001 AND ABS(l.Average - 5.0) < 0.001);
ADVANCE(T#500ms);
l(Value := 9.0);
ASSERT_EQ(1, l.Count);
ADVANCE(T#500ms);
l(Value := 1.0);
ASSERT_EQ(2, l.Count);
ASSERT_TRUE(ABS(l.Samples[2] - 1.0) < 0.001);
ASSERT_TRUE(ABS(l.Minimum - 1.0) < 0.001);
ASSERT_TRUE(ABS(l.Maximum - 5.0) < 0.001);
ASSERT_TRUE(ABS(l.Average - 3.0) < 0.001);
(* fill and wrap: 70 samples in all *)
FOR i := 3 TO 70 DO
    ADVANCE(T#1s);
    l(Value := INT_TO_REAL(i));
END_FOR;
ASSERT_EQ(64, l.Count);
ASSERT_EQ(6, l.Newest);
ASSERT_TRUE(ABS(l.Samples[6] - 70.0) < 0.001);
ASSERT_TRUE(ABS(l.Minimum - 7.0) < 0.001);
ASSERT_TRUE(ABS(l.Maximum - 70.0) < 0.001);
ASSERT_TRUE(ABS(l.Average - 38.5) < 0.001);
(* the next sample comes one Interval later, not before *)
ADVANCE(T#500ms);
l(Value := 71.0);
ASSERT_EQ(6, l.Newest);
ADVANCE(T#500ms);
l(Value := 71.0);
ASSERT_EQ(7, l.Newest);
(* paused, then cleared *)
ADVANCE(T#5s);
l(Value := 99.0, Enable := FALSE);
ASSERT_TRUE(ABS(l.Maximum - 71.0) < 0.001);
l(Clear := TRUE);
ASSERT_EQ(0, l.Count);
ASSERT_TRUE(ABS(l.Average) < 0.001 AND ABS(l.Maximum) < 0.001 AND ABS(l.Minimum) < 0.001);
l(Clear := FALSE, Enable := TRUE, Value := -4.0);
ASSERT_EQ(1, l.Newest);
ASSERT_TRUE(ABS(l.Minimum + 4.0) < 0.001 AND ABS(l.Maximum + 4.0) < 0.001);
END_TEST

TEST scale_out_to_an_output_word
VAR s : RB_ScaleOut; END_VAR
s(Value := 50.0);
ASSERT_EQ(13824, s.Raw);
ASSERT_FALSE(s.Limited OR s.Error);
s(Value := 100.0);
ASSERT_EQ(27648, s.Raw);
ASSERT_FALSE(s.Limited);
s(Value := 120.0);
ASSERT_EQ(27648, s.Raw);
ASSERT_TRUE(s.Limited);
s(Value := -5.0);
ASSERT_EQ(0, s.Raw);
ASSERT_TRUE(s.Limited);
s(Value := 0.5);
ASSERT_EQ(138, s.Raw);
s(Value := 0.0);
ASSERT_EQ(0, s.Raw);
ASSERT_FALSE(s.Limited);
(* the fail value on a fault *)
s(Value := 50.0, Fault := TRUE, FailValue := 25.0);
ASSERT_EQ(6912, s.Raw);
s(Fault := FALSE);
ASSERT_EQ(13824, s.Raw);
(* a reversed range and a live-zero raw range *)
s(Value := 25.0, EngMin := 100.0, EngMax := 0.0);
ASSERT_EQ(20736, s.Raw);
s(Value := 50.0, EngMin := 0.0, EngMax := 100.0, RawMin := 5530.0);
ASSERT_EQ(16589, s.Raw);
s(EngMax := 0.0);
ASSERT_TRUE(s.Error);
ASSERT_EQ(UDINT#1, s.ErrorID);
ASSERT_EQ(5530, s.Raw);
ASSERT_FALSE(s.Limited);
s(EngMax := 200.0);
ASSERT_FALSE(s.Error);
ASSERT_EQ(UDINT#0, s.ErrorID);
END_TEST

TEST drum_steps_by_time_and_event
VAR d : RB_Drum; p : ARRAY[1..16] OF WORD; t : ARRAY[1..16] OF TIME; END_VAR
p[1] := WORD#16#0001; p[2] := WORD#16#0006; p[3] := WORD#16#0010;
t[1] := T#2s; t[2] := T#0s; t[3] := T#1s;
d(Patterns := p, Times := t, Count := 3);
ASSERT_EQ(1, d.StepNo);
ASSERT_EQ(WORD#16#0001, d.Out);
ADVANCE(T#5s);
d();
ASSERT_EQ(1, d.StepNo);
d(Run := TRUE);
ADVANCE(T#1900ms);
d();
ASSERT_EQ(1, d.StepNo);
ASSERT_EQ(T#1900ms, d.StepTime);
ADVANCE(T#100ms);
d();
ASSERT_EQ(2, d.StepNo);
ASSERT_EQ(WORD#16#0006, d.Out);
ASSERT_EQ(T#0s, d.StepTime);
(* T#0s: waits for Next *)
ADVANCE(T#10s);
d();
ASSERT_EQ(2, d.StepNo);
d(Next := TRUE);
ASSERT_EQ(3, d.StepNo);
d(Next := FALSE);
(* paused while Run is FALSE *)
ADVANCE(T#500ms);
d();
ADVANCE(T#100ms);
d(Run := FALSE);
ADVANCE(T#100ms);
d(Run := FALSE);
ADVANCE(T#100ms);
d(Run := TRUE);
ADVANCE(T#300ms);
d();
ASSERT_EQ(3, d.StepNo);
ADVANCE(T#100ms);
d();
ASSERT_EQ(1, d.StepNo);
END_TEST

TEST drum_one_shot_reset_and_count
VAR d : RB_Drum; p : ARRAY[1..16] OF WORD; t : ARRAY[1..16] OF TIME; END_VAR
p[1] := WORD#16#00F0; p[2] := WORD#16#0F00;
d(Patterns := p, Times := t, Count := 2, Cyclic := FALSE);
d(Next := TRUE);
ASSERT_EQ(2, d.StepNo);
d(Next := FALSE);
d(Next := TRUE);
ASSERT_TRUE(d.Done);
ASSERT_EQ(2, d.StepNo);
ASSERT_EQ(WORD#16#0F00, d.Out);
d(Next := FALSE);
d(Next := TRUE);
ASSERT_EQ(2, d.StepNo);
d(Next := FALSE, Reset := TRUE);
ASSERT_EQ(1, d.StepNo);
ASSERT_FALSE(d.Done);
d(Reset := FALSE, Count := 0);
ASSERT_TRUE(d.Error);
ASSERT_EQ(UDINT#1, d.ErrorID);
ASSERT_EQ(WORD#0, d.Out);
ASSERT_EQ(0, d.StepNo);
d(Count := 17);
ASSERT_TRUE(d.Error);
d(Count := 1);
ASSERT_FALSE(d.Error);
ASSERT_EQ(1, d.StepNo);
d(Count := 16);
ASSERT_FALSE(d.Error);
ASSERT_EQ(UDINT#0, d.ErrorID);
ASSERT_EQ(1, d.StepNo);
(* a smaller Count while beyond it: back to step 1 *)
d(Next := TRUE);
d(Next := FALSE);
d(Next := TRUE);
d(Next := FALSE);
ASSERT_EQ(3, d.StepNo);
d(Count := 2);
ASSERT_EQ(1, d.StepNo);
END_TEST
