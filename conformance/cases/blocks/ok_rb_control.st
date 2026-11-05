(* spec: [blocks.mode] [blocks.fault] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_PID (F06.PID) and RB_OnOff (F06.ONOFF). Every call
   passes the inputs that matter: block inputs keep their last value. *)
TEST pid_proportional_both_actions
VAR c : RB_PID; d : RB_PID; END_VAR
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, Kp := 2.0);
ASSERT_TRUE(ABS(c.Out - 20.0) < 0.001);
ASSERT_FALSE(c.Saturated);
d(Mode := RB_MODE#Auto, SP := 50.0, PV := 60.0, Kp := 2.0, Direct := TRUE);
ASSERT_TRUE(ABS(d.Out - 20.0) < 0.001);
d(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, Kp := 2.0, Direct := TRUE);
ASSERT_TRUE(ABS(d.Out) < 0.001);
ASSERT_TRUE(d.Saturated);
END_TEST

TEST pid_integral_adds_up_over_time
VAR c : RB_PID; i : INT; END_VAR
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, Kp := 1.0, Ti := T#1s);
ASSERT_TRUE(ABS(c.Out - 10.0) < 0.001);
FOR i := 1 TO 10 DO
    ADVANCE(T#100ms);
    c(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, Kp := 1.0, Ti := T#1s);
END_FOR;
ASSERT_TRUE(ABS(c.Out - 20.0) < 0.001);
(* without integral time the output stays at the proportional part *)
ADVANCE(T#1s);
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, Kp := 1.0, Ti := T#0s);
ASSERT_TRUE(ABS(c.Out - 10.0) < 0.001);
END_TEST

TEST pid_anti_windup_leaves_saturation_at_once
VAR c : RB_PID; i : INT; END_VAR
FOR i := 1 TO 100 DO
    ADVANCE(T#100ms);
    c(Mode := RB_MODE#Auto, SP := 60.0, PV := 0.0, Kp := 1.0, Ti := T#1s);
END_FOR;
ASSERT_TRUE(ABS(c.Out - 100.0) < 0.001);
ASSERT_TRUE(c.Saturated);
(* the error turns negative: the output leaves the limit in the same call *)
ADVANCE(T#100ms);
c(Mode := RB_MODE#Auto, SP := 60.0, PV := 61.0, Kp := 1.0, Ti := T#1s);
ASSERT_TRUE(c.Out < 100.0);
ASSERT_FALSE(c.Saturated);
(* and at the lower limit too *)
FOR i := 1 TO 100 DO
    ADVANCE(T#100ms);
    c(Mode := RB_MODE#Auto, SP := 0.0, PV := 60.0, Kp := 1.0, Ti := T#1s);
END_FOR;
ASSERT_TRUE(ABS(c.Out) < 0.001);
ADVANCE(T#100ms);
c(Mode := RB_MODE#Auto, SP := 61.0, PV := 60.0, Kp := 1.0, Ti := T#1s);
ASSERT_TRUE(c.Out > 0.0);
END_TEST

TEST pid_derivative_on_the_measurement
VAR c : RB_PID; d : RB_PID; END_VAR
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, Kp := 1.0, Td := T#1s);
ASSERT_TRUE(ABS(c.Out - 10.0) < 0.001);
ADVANCE(T#100ms);
(* a set-point step: no derivative kick *)
c(Mode := RB_MODE#Auto, SP := 60.0, PV := 40.0, Kp := 1.0, Td := T#1s);
ASSERT_TRUE(ABS(c.Out - 20.0) < 0.001);
ADVANCE(T#100ms);
(* the measurement rises 1 in 0.1 s: D = -1 * 1 s * 10/s *)
c(Mode := RB_MODE#Auto, SP := 60.0, PV := 41.0, Kp := 1.0, Td := T#1s);
ASSERT_TRUE(ABS(c.Out - 9.0) < 0.001);
(* direct action: the sign of the derivative follows *)
d(Mode := RB_MODE#Auto, SP := 20.0, PV := 40.0, Kp := 1.0, Td := T#1s, Direct := TRUE);
ADVANCE(T#100ms);
d(Mode := RB_MODE#Auto, SP := 20.0, PV := 41.0, Kp := 1.0, Td := T#1s, Direct := TRUE);
ASSERT_TRUE(ABS(d.Out - 31.0) < 0.001);
(* two calls at the same instant: no derivative *)
d(Mode := RB_MODE#Auto, SP := 20.0, PV := 45.0, Kp := 1.0, Td := T#1s, Direct := TRUE);
ASSERT_TRUE(ABS(d.Out - 25.0) < 0.001);
END_TEST

TEST pid_manual_off_and_bumpless_transfer
VAR c : RB_PID; END_VAR
c(Mode := RB_MODE#Manual, SP := 50.0, PV := 50.0, Kp := 1.0, Ti := T#10s, ManValue := 40.0);
ASSERT_TRUE(ABS(c.Out - 40.0) < 0.001);
ASSERT_FALSE(c.Saturated);
c(Mode := RB_MODE#Manual, SP := 50.0, PV := 50.0, Kp := 1.0, Ti := T#10s, ManValue := 140.0);
ASSERT_TRUE(ABS(c.Out - 100.0) < 0.001);
ASSERT_FALSE(c.Saturated);
c(Mode := RB_MODE#Manual, SP := 50.0, PV := 50.0, Kp := 1.0, Ti := T#10s, ManValue := 40.0);
ADVANCE(T#100ms);
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 50.0, Kp := 1.0, Ti := T#10s);
ASSERT_TRUE(ABS(c.Out - 40.0) < 0.001);
c(Mode := RB_MODE#Off, SP := 50.0, PV := 50.0, Kp := 1.0, Ti := T#10s, OutMin := 5.0);
ASSERT_TRUE(ABS(c.Out - 5.0) < 0.001);
ASSERT_FALSE(c.Saturated);
(* from Off, Auto starts at the minimum, not with a jump *)
ADVANCE(T#100ms);
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 50.0, Kp := 1.0, Ti := T#10s, OutMin := 5.0);
ASSERT_TRUE(ABS(c.Out - 5.0) < 0.001);
ASSERT_TRUE(c.Saturated);
END_TEST

TEST pid_invalid_range_is_a_fault
VAR c : RB_PID; END_VAR
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, Kp := 1.0, OutMin := 10.0, OutMax := 10.0);
ASSERT_TRUE(c.Error);
ASSERT_EQ(UDINT#1, c.ErrorID);
ASSERT_TRUE(ABS(c.Out - 10.0) < 0.001);
ASSERT_FALSE(c.Saturated);
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, Kp := 1.0, OutMin := 0.0, OutMax := 100.0);
ASSERT_TRUE(c.Error);
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 40.0, Kp := 1.0, OutMin := 0.0, OutMax := 100.0, Reset := TRUE);
ASSERT_FALSE(c.Error);
ASSERT_EQ(UDINT#0, c.ErrorID);
ASSERT_TRUE(ABS(c.Out - 10.0) < 0.001);
END_TEST

TEST onoff_heating_with_hysteresis
VAR h : RB_OnOff; END_VAR
h(Enable := TRUE, SP := 20.0, PV := 19.5, Hysteresis := 2.0);
ASSERT_FALSE(h.Out);
h(Enable := TRUE, SP := 20.0, PV := 19.0, Hysteresis := 2.0);
ASSERT_TRUE(h.Out);
h(Enable := TRUE, SP := 20.0, PV := 20.9, Hysteresis := 2.0);
ASSERT_TRUE(h.Out);
h(Enable := TRUE, SP := 20.0, PV := 21.0, Hysteresis := 2.0);
ASSERT_FALSE(h.Out);
h(Enable := TRUE, SP := 20.0, PV := 19.1, Hysteresis := 2.0);
ASSERT_FALSE(h.Out);
h(Enable := TRUE, SP := 20.0, PV := 18.0, Hysteresis := -2.0);
ASSERT_TRUE(h.Out);
h(Enable := FALSE, SP := 20.0, PV := 18.0, Hysteresis := 2.0);
ASSERT_FALSE(h.Out);
END_TEST

TEST onoff_cooling_with_hysteresis
VAR c : RB_OnOff; END_VAR
c(Enable := TRUE, SP := 5.0, PV := 6.0, Hysteresis := 2.0, Direct := TRUE);
ASSERT_TRUE(c.Out);
c(Enable := TRUE, SP := 5.0, PV := 4.1, Hysteresis := 2.0, Direct := TRUE);
ASSERT_TRUE(c.Out);
c(Enable := TRUE, SP := 5.0, PV := 4.0, Hysteresis := 2.0, Direct := TRUE);
ASSERT_FALSE(c.Out);
c(Enable := TRUE, SP := 5.0, PV := 5.9, Hysteresis := 2.0, Direct := TRUE);
ASSERT_FALSE(c.Out);
END_TEST

TEST pid_anti_windup_bounds_exactly
VAR c : RB_PID; i : INT; END_VAR
(* high limit: P = 60, the integral held at 40 *)
FOR i := 1 TO 50 DO
    ADVANCE(T#100ms);
    c(Mode := RB_MODE#Auto, SP := 60.0, PV := 0.0, Kp := 1.0, Ti := T#1s, Td := T#1s);
END_FOR;
(* the measurement rises 1 in 0.1 s: P = 59, D = -10, I = 40 + 5.9 *)
ADVANCE(T#100ms);
c(Mode := RB_MODE#Auto, SP := 60.0, PV := 1.0, Kp := 1.0, Ti := T#1s, Td := T#1s);
ASSERT_TRUE(ABS(c.Out - 94.9) < 0.01);
(* the error turns: P = -1, I = 45.9 - 0.1, D = 0 *)
ADVANCE(T#100ms);
c(Mode := RB_MODE#Auto, SP := 0.0, PV := 1.0, Kp := 1.0, Ti := T#1s, Td := T#1s);
ASSERT_TRUE(ABS(c.Out - 44.8) < 0.01);
(* low limit: P = -60, the integral held at 60 *)
FOR i := 1 TO 50 DO
    ADVANCE(T#100ms);
    c(Mode := RB_MODE#Auto, SP := 0.0, PV := 60.0, Kp := 1.0, Ti := T#1s, Td := T#1s);
END_FOR;
ASSERT_TRUE(ABS(c.Out) < 0.01);
(* the measurement falls 1 in 0.1 s: P = -59, D = +10, I = 60 - 5.9 *)
ADVANCE(T#100ms);
c(Mode := RB_MODE#Auto, SP := 0.0, PV := 59.0, Kp := 1.0, Ti := T#1s, Td := T#1s);
ASSERT_TRUE(ABS(c.Out - 5.1) < 0.01);
END_TEST

TEST pid_bumpless_with_an_error_present
VAR c : RB_PID; END_VAR
c(Mode := RB_MODE#Manual, SP := 50.0, PV := 45.0, Kp := 1.0, Ti := T#10s, ManValue := 40.0);
ADVANCE(T#100ms);
c(Mode := RB_MODE#Auto, SP := 50.0, PV := 45.0, Kp := 1.0, Ti := T#10s);
ASSERT_TRUE(ABS(c.Out - 40.05) < 0.001);
END_TEST
