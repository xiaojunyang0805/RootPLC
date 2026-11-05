(* spec: [blocks.testable] [blocks.library]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of the S2 signal blocks: RB_CycleTime (F03.CYCLETIME),
   RB_FilterPT1 (F01.FILTER.PT1), RB_MovingAverage (F01.AVERAGE), RB_Ramp
   (F01.RAMP), RB_Deadband (F01.DEADBAND), RB_Debounce (F01.DEBOUNCE).
   Time comes from ADVANCE (the VM clock), as on a PLC. *)
TEST cycle_time_measures_seconds
VAR c : RB_CycleTime; END_VAR
c();
ASSERT_TRUE(c.FirstCall);
ASSERT_TRUE(ABS(c.Seconds) < 0.000001);
ADVANCE(T#250ms);
c();
ASSERT_FALSE(c.FirstCall);
ASSERT_TRUE(ABS(c.Seconds - 0.25) < 0.000001);
ADVANCE(T#10ms);
c();
ASSERT_TRUE(ABS(c.Seconds - 0.01) < 0.000001);
c();
ASSERT_TRUE(ABS(c.Seconds) < 0.000001);
END_TEST

TEST cycle_time_survives_the_daily_restart
VAR c : RB_CycleTime; i : INT; total : LREAL; END_VAR
c();
FOR i := 1 TO 26 DO
    ADVANCE(T#1h);
    c();
    total := total + c.Seconds;
END_FOR;
ASSERT_TRUE(ABS(total - 93600.0) < 0.001);
ASSERT_TRUE(ABS(c.Seconds - 3600.0) < 0.001);
END_TEST

TEST pt1_settles_with_its_time_constant
VAR f : RB_FilterPT1; i : INT; END_VAR
f(In := 10.0, T := T#1s);
ASSERT_TRUE(ABS(f.Out - 10.0) < 0.0001);
(* a step from 10 to 20: after one time constant about 63% of the step *)
FOR i := 1 TO 100 DO
    ADVANCE(T#10ms);
    f(In := 20.0, T := T#1s);
END_FOR;
ASSERT_TRUE(f.Out > 16.2 AND f.Out < 16.4);
FOR i := 1 TO 500 DO
    ADVANCE(T#10ms);
    f(In := 20.0, T := T#1s);
END_FOR;
ASSERT_TRUE(ABS(f.Out - 20.0) < 0.1);
(* falling as well *)
ADVANCE(T#1s);
f(In := 0.0, T := T#1s);
ASSERT_TRUE(f.Out > 9.9 AND f.Out < 10.1);
END_TEST

TEST pt1_track_and_zero_time_constant_pass_through
VAR f : RB_FilterPT1; g : RB_FilterPT1; END_VAR
f(In := 0.0, T := T#5s);
ADVANCE(T#100ms);
f(In := 50.0, T := T#5s, Track := TRUE);
ASSERT_TRUE(ABS(f.Out - 50.0) < 0.0001);
ADVANCE(T#100ms);
f(In := 0.0, T := T#5s, Track := FALSE);
ASSERT_TRUE(f.Out > 48.0 AND f.Out < 50.0);
g(In := 0.0, T := T#0s);
ADVANCE(T#100ms);
g(In := 7.0, T := T#0s);
ASSERT_TRUE(ABS(g.Out - 7.0) < 0.0001);
(* two calls at the same instant *)
g(In := 3.0, T := T#0s);
ASSERT_TRUE(ABS(g.Out - 3.0) < 0.0001);
END_TEST

TEST average_over_the_window
VAR a : RB_MovingAverage; END_VAR
a(In := 2.0, Window := 3);
ASSERT_TRUE(ABS(a.Out - 2.0) < 0.0001);
ASSERT_FALSE(a.Valid);
a(In := 4.0, Window := 3);
ASSERT_TRUE(ABS(a.Out - 3.0) < 0.0001);
a(In := 6.0, Window := 3);
ASSERT_TRUE(ABS(a.Out - 4.0) < 0.0001);
ASSERT_TRUE(a.Valid);
a(In := 8.0, Window := 3);
ASSERT_TRUE(ABS(a.Out - 6.0) < 0.0001);
a(In := 1.0, Window := 3, Reset := TRUE);
ASSERT_TRUE(ABS(a.Out - 1.0) < 0.0001);
ASSERT_FALSE(a.Valid);
END_TEST

TEST average_window_is_clamped
VAR a : RB_MovingAverage; b : RB_MovingAverage; i : INT; END_VAR
a(In := 5.0, Window := 0);
ASSERT_TRUE(a.Valid);
a(In := 9.0, Window := 0);
ASSERT_TRUE(ABS(a.Out - 9.0) < 0.0001);
FOR i := 1 TO 31 DO
    b(In := 1.0, Window := 40);
END_FOR;
ASSERT_FALSE(b.Valid);
b(In := 33.0, Window := 40);
ASSERT_TRUE(b.Valid);
ASSERT_TRUE(ABS(b.Out - 2.0) < 0.0001);
END_TEST

TEST ramp_limits_rise_and_fall
VAR r : RB_Ramp; i : INT; END_VAR
r(In := 0.0, RiseRate := 10.0, FallRate := 20.0);
ASSERT_TRUE(ABS(r.Out) < 0.0001);
ASSERT_FALSE(r.Busy);
ADVANCE(T#500ms);
r(In := 100.0, RiseRate := 10.0, FallRate := 20.0);
ASSERT_TRUE(ABS(r.Out - 5.0) < 0.001);
ASSERT_TRUE(r.Busy);
FOR i := 1 TO 20 DO
    ADVANCE(T#500ms);
    r(In := 100.0, RiseRate := 10.0, FallRate := 20.0);
END_FOR;
ASSERT_TRUE(ABS(r.Out - 100.0) < 0.001);
ASSERT_FALSE(r.Busy);
ADVANCE(T#1s);
r(In := 0.0, RiseRate := 10.0, FallRate := 20.0);
ASSERT_TRUE(ABS(r.Out - 80.0) < 0.001);
FOR i := 1 TO 10 DO
    ADVANCE(T#1s);
    r(In := 0.0, RiseRate := 10.0, FallRate := 20.0);
END_FOR;
ASSERT_TRUE(ABS(r.Out) < 0.001);
END_TEST

TEST ramp_rate_zero_and_track_pass_through
VAR r : RB_Ramp; END_VAR
r(In := 0.0, RiseRate := 0.0, FallRate := 5.0);
ADVANCE(T#100ms);
r(In := 40.0, RiseRate := 0.0, FallRate := 5.0);
ASSERT_TRUE(ABS(r.Out - 40.0) < 0.001);
ADVANCE(T#100ms);
r(In := 0.0, RiseRate := 0.0, FallRate := 5.0);
ASSERT_TRUE(ABS(r.Out - 39.5) < 0.001);
ADVANCE(T#100ms);
r(In := 0.0, RiseRate := 0.0, FallRate := 0.0);
ASSERT_TRUE(ABS(r.Out) < 0.001);
ADVANCE(T#100ms);
r(In := 60.0, RiseRate := 1.0, FallRate := 1.0, Track := TRUE);
ASSERT_TRUE(ABS(r.Out - 60.0) < 0.001);
END_TEST

TEST deadband_holds_until_the_input_moves_enough
VAR d : RB_Deadband; END_VAR
d(In := 10.0, Deadband := 0.5);
ASSERT_TRUE(ABS(d.Out - 10.0) < 0.0001);
d(In := 10.4, Deadband := 0.5);
ASSERT_TRUE(ABS(d.Out - 10.0) < 0.0001);
d(In := 9.5, Deadband := 0.5);
ASSERT_TRUE(ABS(d.Out - 10.0) < 0.0001);
d(In := 10.6, Deadband := 0.5);
ASSERT_TRUE(ABS(d.Out - 10.6) < 0.0001);
d(In := 10.2, Deadband := 0.5);
ASSERT_TRUE(ABS(d.Out - 10.6) < 0.0001);
d(In := 10.0, Deadband := 0.0);
ASSERT_TRUE(ABS(d.Out - 10.0) < 0.0001);
END_TEST

TEST debounce_needs_a_stable_contact
VAR b : RB_Debounce; END_VAR
b(In := TRUE, OnDelay := T#50ms, OffDelay := T#100ms);
ASSERT_FALSE(b.Out);
ADVANCE(T#40ms);
b(In := FALSE, OnDelay := T#50ms, OffDelay := T#100ms);
ADVANCE(T#20ms);
b(In := TRUE, OnDelay := T#50ms, OffDelay := T#100ms);
ADVANCE(T#40ms);
b(In := TRUE, OnDelay := T#50ms, OffDelay := T#100ms);
ASSERT_FALSE(b.Out);
ADVANCE(T#20ms);
b(In := TRUE, OnDelay := T#50ms, OffDelay := T#100ms);
ASSERT_TRUE(b.Out);
(* a short drop is ignored; a long one switches off *)
b(In := FALSE, OnDelay := T#50ms, OffDelay := T#100ms);
ADVANCE(T#90ms);
b(In := FALSE, OnDelay := T#50ms, OffDelay := T#100ms);
ASSERT_TRUE(b.Out);
b(In := TRUE, OnDelay := T#50ms, OffDelay := T#100ms);
b(In := FALSE, OnDelay := T#50ms, OffDelay := T#100ms);
ADVANCE(T#90ms);
b(In := FALSE, OnDelay := T#50ms, OffDelay := T#100ms);
ASSERT_TRUE(b.Out);
ADVANCE(T#20ms);
b(In := FALSE, OnDelay := T#50ms, OffDelay := T#100ms);
ASSERT_FALSE(b.Out);
END_TEST
