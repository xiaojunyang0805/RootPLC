(* spec: [blocks.fault] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_Blink (F03.BLINK), RB_PWM (F06.PWM), RB_PulseRate
   (F01.PULSE), RB_ShiftTrack (F11.TRACK), RB_Vote2oo3 (F01.VOTE) and
   RB_Bypass (F02.BYPASS). Every call passes the inputs that matter: block
   inputs keep their last value. *)
TEST blink_on_and_off
VAR b : RB_Blink; END_VAR
b(Enable := FALSE);
ASSERT_FALSE(b.Out);
ASSERT_EQ(UDINT#0, b.Pulses);
b(Enable := TRUE);
ASSERT_TRUE(b.Out);
ASSERT_EQ(UDINT#1, b.Pulses);
ADVANCE(T#400ms);
b();
ASSERT_TRUE(b.Out);
ADVANCE(T#100ms);
b();
ASSERT_FALSE(b.Out);
ADVANCE(T#499ms);
b();
ASSERT_FALSE(b.Out);
ADVANCE(T#1ms);
b();
ASSERT_TRUE(b.Out);
ASSERT_EQ(UDINT#2, b.Pulses);
(* the phase is kept: a late call does not shift the next edge *)
ADVANCE(T#600ms);
b();
ASSERT_FALSE(b.Out);
ADVANCE(T#400ms);
b();
ASSERT_TRUE(b.Out);
ADVANCE(T#100ms);
b();
ASSERT_TRUE(b.Out);
(* off, then on again: starts on *)
b(Enable := FALSE);
ASSERT_FALSE(b.Out);
ADVANCE(T#250ms);
b(Enable := TRUE);
ASSERT_TRUE(b.Out);
ASSERT_EQ(UDINT#4, b.Pulses);
(* asymmetric *)
b(Enable := FALSE);
b(Enable := TRUE, OnTime := T#200ms, OffTime := T#800ms);
ADVANCE(T#200ms);
b();
ASSERT_FALSE(b.Out);
ADVANCE(T#700ms);
b();
ASSERT_FALSE(b.Out);
ADVANCE(T#100ms);
b();
ASSERT_TRUE(b.Out);
END_TEST

TEST pwm_duty_and_period
VAR p : RB_PWM; END_VAR
p(In := 25.0);
ASSERT_TRUE(p.Out);
ASSERT_EQ(T#500ms, p.OnTime);
ASSERT_FALSE(p.Error);
ADVANCE(T#400ms);
p();
ASSERT_TRUE(p.Out);
ADVANCE(T#100ms);
p();
ASSERT_FALSE(p.Out);
(* a new duty waits for the next period *)
ADVANCE(T#100ms);
p(In := 75.0);
ASSERT_FALSE(p.Out);
ASSERT_EQ(T#500ms, p.OnTime);
ADVANCE(T#1399ms);
p();
ASSERT_FALSE(p.Out);
ADVANCE(T#1ms);
p();
ASSERT_TRUE(p.Out);
ASSERT_EQ(T#1500ms, p.OnTime);
ADVANCE(T#1499ms);
p();
ASSERT_TRUE(p.Out);
ADVANCE(T#1ms);
p();
ASSERT_FALSE(p.Out);
(* disabled *)
p(Enable := FALSE);
ASSERT_FALSE(p.Out);
ASSERT_EQ(T#0s, p.OnTime);
p(Enable := TRUE, In := 0.0);
ASSERT_FALSE(p.Out);
p(Enable := FALSE);
p(Enable := TRUE, In := 150.0);
ASSERT_TRUE(p.Out);
ASSERT_EQ(T#2s, p.OnTime);
ADVANCE(T#1999ms);
p();
ASSERT_TRUE(p.Out);
END_TEST

TEST pwm_minimum_pulse_and_errors
VAR p : RB_PWM; END_VAR
p(In := 10.0, MinPulse := T#300ms);
ASSERT_EQ(T#0s, p.OnTime);
ASSERT_FALSE(p.Out);
p(Enable := FALSE);
p(Enable := TRUE, In := 90.0);
ASSERT_EQ(T#2s, p.OnTime);
p(Enable := FALSE);
p(Enable := TRUE, In := 15.0);
ASSERT_EQ(T#300ms, p.OnTime);
p(Enable := FALSE);
p(Enable := TRUE, In := 85.0);
ASSERT_EQ(T#1700ms, p.OnTime);
p(Period := T#0s);
ASSERT_TRUE(p.Error);
ASSERT_EQ(UDINT#1, p.ErrorID);
ASSERT_FALSE(p.Out);
p(Period := T#1s);
ASSERT_FALSE(p.Error);
ASSERT_EQ(UDINT#0, p.ErrorID);
ASSERT_TRUE(p.Out);
END_TEST

TEST pulse_rate_over_a_window
VAR r : RB_PulseRate; i : INT; END_VAR
r(Factor := 0.5);
FOR i := 1 TO 20 DO
    ADVANCE(T#50ms);
    r(Pulse := (i MOD 2) = 1);
END_FOR;
ASSERT_TRUE(ABS(r.Rate - 18000.0) < 0.001);
ASSERT_TRUE(ABS(r.Total - 5.0) < 0.0001);
ASSERT_EQ(UDINT#0, r.Pulses);
(* the next window, at half the pulse rate, per minute *)
FOR i := 1 TO 20 DO
    ADVANCE(T#50ms);
    r(Pulse := (i MOD 4) = 1, TimeBase := T#1m);
    IF i = 19 THEN
        ASSERT_EQ(UDINT#5, r.Pulses);
        ASSERT_TRUE(ABS(r.Rate - 18000.0) < 0.001);
    END_IF;
END_FOR;
ASSERT_TRUE(ABS(r.Rate - 150.0) < 0.001);
ASSERT_TRUE(ABS(r.Total - 7.5) < 0.0001);
(* no pulses: rate 0 after a window *)
ADVANCE(T#1s);
r(Pulse := FALSE);
ASSERT_TRUE(ABS(r.Rate) < 0.001);
r(Reset := TRUE);
ASSERT_TRUE(ABS(r.Total) < 0.0001);
r(Reset := FALSE, Window := T#0s, Pulse := TRUE);
ASSERT_TRUE(r.Error);
ASSERT_EQ(UDINT#1, r.ErrorID);
ASSERT_EQ(UDINT#0, r.Pulses);
r(Window := T#2s, Pulse := FALSE);
ASSERT_FALSE(r.Error);
ASSERT_EQ(UDINT#0, r.ErrorID);
END_TEST

TEST shift_track_moves_parts
VAR s : RB_ShiftTrack; i : INT; END_VAR
s(ReadPos := 3);
ASSERT_EQ(0, s.Occupied);
s(Shift := TRUE, InValue := 7);
ASSERT_EQ(DINT#7, s.Positions[1]);
s(Shift := FALSE);
s(Shift := TRUE, InValue := 0);
s(Shift := FALSE);
ASSERT_EQ(DINT#7, s.Positions[2]);
ASSERT_EQ(DINT#0, s.Positions[1]);
ASSERT_EQ(DINT#0, s.AtRead);
s(Shift := TRUE, InValue := 9);
ASSERT_EQ(DINT#7, s.AtRead);
ASSERT_EQ(2, s.Occupied);
(* the ejector takes it: removed there *)
s(Shift := FALSE, Remove := TRUE);
ASSERT_EQ(DINT#0, s.AtRead);
ASSERT_EQ(1, s.Occupied);
s(Remove := FALSE);
(* an entry falls out after position 64 *)
FOR i := 1 TO 63 DO
    s(Shift := TRUE, InValue := 0);
    s(Shift := FALSE);
END_FOR;
ASSERT_EQ(DINT#9, s.Positions[64]);
s(Shift := TRUE, InValue := 0);
ASSERT_EQ(0, s.Occupied);
s(Shift := FALSE, InValue := 5);
s(Shift := TRUE);
s(Shift := FALSE, ReadPos := 1);
ASSERT_EQ(DINT#5, s.AtRead);
s(Clear := TRUE);
ASSERT_EQ(0, s.Occupied);
ASSERT_EQ(DINT#0, s.AtRead);
END_TEST

TEST shift_track_read_position_range
VAR s : RB_ShiftTrack; END_VAR
s(Shift := TRUE, InValue := 4, ReadPos := 0);
ASSERT_TRUE(s.Error);
ASSERT_EQ(UDINT#1, s.ErrorID);
ASSERT_EQ(DINT#0, s.AtRead);
s(Shift := FALSE, ReadPos := 65, Remove := TRUE);
ASSERT_TRUE(s.Error);
ASSERT_EQ(1, s.Occupied);
s(ReadPos := 64, Remove := FALSE);
ASSERT_FALSE(s.Error);
ASSERT_EQ(UDINT#0, s.ErrorID);
s(ReadPos := 1);
ASSERT_EQ(DINT#4, s.AtRead);
END_TEST

TEST vote_median_average_and_deviation
VAR v : RB_Vote2oo3; END_VAR
v(A := 10.0, B := 11.0, C := 50.0);
ASSERT_TRUE(ABS(v.Value - 11.0) < 0.001);
ASSERT_EQ(3, v.Healthy);
ASSERT_FALSE(v.DevA OR v.DevB);
ASSERT_TRUE(v.DevC);
v(A := 50.0, B := 10.0, C := 11.0);
ASSERT_TRUE(ABS(v.Value - 11.0) < 0.001);
ASSERT_TRUE(v.DevA);
v(A := 11.0, B := 50.0, C := 10.0);
ASSERT_TRUE(ABS(v.Value - 11.0) < 0.001);
ASSERT_TRUE(v.DevB);
v(A := 10.0, B := 50.0, C := 11.0);
ASSERT_TRUE(ABS(v.Value - 11.0) < 0.001);
v(A := 11.0, B := 10.0, C := 50.0);
ASSERT_TRUE(ABS(v.Value - 11.0) < 0.001);
v(A := 50.0, B := 11.0, C := 10.0);
ASSERT_TRUE(ABS(v.Value - 11.0) < 0.001);
(* exactly MaxDev away is not a deviation *)
v(A := 9.0, B := 11.0, C := 13.0);
ASSERT_FALSE(v.DevA OR v.DevB OR v.DevC);
v(A := 11.0, B := 13.0, C := 9.0);
ASSERT_FALSE(v.DevA OR v.DevB OR v.DevC);
(* one unhealthy: the average of the other two *)
v(A := 10.0, B := 11.0, C := 50.0, OkC := FALSE);
ASSERT_TRUE(ABS(v.Value - 10.5) < 0.001);
ASSERT_EQ(2, v.Healthy);
ASSERT_FALSE(v.DevC);
v(OkC := TRUE, OkA := FALSE);
ASSERT_TRUE(ABS(v.Value - 30.5) < 0.001);
ASSERT_TRUE(v.DevB AND v.DevC);
ASSERT_FALSE(v.DevA);
v(OkA := TRUE, OkB := FALSE, A := 20.0, C := 22.0);
ASSERT_TRUE(ABS(v.Value - 21.0) < 0.001);
(* one left, then none: the last good value stays *)
v(OkA := FALSE);
ASSERT_TRUE(ABS(v.Value - 22.0) < 0.001);
ASSERT_EQ(1, v.Healthy);
ASSERT_FALSE(v.Error);
v(OkC := FALSE, C := 99.0);
ASSERT_TRUE(v.Error);
ASSERT_EQ(UDINT#1, v.ErrorID);
ASSERT_TRUE(ABS(v.Value - 22.0) < 0.001);
ASSERT_FALSE(v.DevA OR v.DevB OR v.DevC);
v(OkB := TRUE, B := 5.0);
ASSERT_FALSE(v.Error);
ASSERT_EQ(UDINT#0, v.ErrorID);
ASSERT_TRUE(ABS(v.Value - 5.0) < 0.001);
END_TEST

TEST bypass_with_key_and_time_limit
VAR y : RB_Bypass; END_VAR
y(Cond := FALSE, MaxTime := T#10s);
ASSERT_FALSE(y.Out);
(* no key: no bypass *)
y(Request := TRUE);
ASSERT_FALSE(y.Active);
y(Request := FALSE, Permit := TRUE);
y(Request := TRUE);
ASSERT_TRUE(y.Active);
ASSERT_TRUE(y.Out);
ASSERT_EQ(UDINT#1, y.Uses);
ASSERT_EQ(T#10s, y.Remaining);
ADVANCE(T#4s);
y(Request := FALSE);
ASSERT_EQ(T#6s, y.Remaining);
(* a second request while active changes nothing *)
y(Request := TRUE);
ASSERT_EQ(UDINT#1, y.Uses);
ADVANCE(T#6s);
y(Request := FALSE);
ASSERT_TRUE(y.Expired);
ASSERT_FALSE(y.Active);
ASSERT_FALSE(y.Out);
ASSERT_EQ(T#0s, y.Remaining);
y();
ASSERT_FALSE(y.Expired);
(* the condition itself still counts *)
y(Cond := TRUE);
ASSERT_TRUE(y.Out);
(* cancel, and the key turned back *)
y(Cond := FALSE, Request := TRUE);
ASSERT_TRUE(y.Active);
ASSERT_EQ(T#10s, y.Remaining);
y(Request := FALSE, Cancel := TRUE);
ASSERT_FALSE(y.Active);
y(Cancel := FALSE, Request := TRUE);
ASSERT_TRUE(y.Active);
ASSERT_EQ(UDINT#3, y.Uses);
y(Request := FALSE, Permit := FALSE);
ASSERT_FALSE(y.Active);
ASSERT_FALSE(y.Out);
END_TEST
