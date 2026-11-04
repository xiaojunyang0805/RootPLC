TEST hidden_first_calls
VAR pid : FB_PID; END_VAR
pid(setpoint := 1.0, actual := 0.0, kp := 2.0, ti_s := 1.0, td_s := 0.0,
    cycle_s := 0.1, out_min := -10.0, out_max := 10.0);
ASSERT_TRUE(ABS(pid.out - 2.2) < 0.0001);
pid();
ASSERT_TRUE(ABS(pid.out - 2.4) < 0.0001);
END_TEST

TEST hidden_antiwindup
VAR pid : FB_PID; i : INT; END_VAR
(* P alone exceeds the limit: 25 calls against it must not wind up the
   integral (without anti-windup it would reach 10) *)
FOR i := 1 TO 25 DO
    pid(setpoint := 1.0, actual := 0.0, kp := 4.0, ti_s := 1.0, td_s := 0.0,
        cycle_s := 0.1, out_min := -3.0, out_max := 3.0);
END_FOR;
ASSERT_TRUE(ABS(pid.out - 3.0) < 0.0001);
ASSERT_TRUE(pid.saturated);
(* the setpoint drops: the output follows at once *)
pid(setpoint := -0.5);
ASSERT_TRUE(ABS(pid.out - (-2.2)) < 0.0001);
ASSERT_FALSE(pid.saturated);
END_TEST

TEST hidden_saturation_low_side
VAR pid : FB_PID; i : INT; END_VAR
FOR i := 1 TO 30 DO
    pid(setpoint := 0.0, actual := 1.0, kp := 1.0, ti_s := 0.5, td_s := 0.0,
        cycle_s := 0.1, out_min := -2.1, out_max := 2.0);
END_FOR;
ASSERT_TRUE(ABS(pid.out - (-2.0)) < 0.0001);
(* I stops at -1.0: the next step would give u = -2.2 < -2.1 *)
pid(setpoint := 2.0);
ASSERT_TRUE(ABS(pid.out - 0.2) < 0.0001);
END_TEST

TEST hidden_derivative
VAR pid : FB_PID; END_VAR
pid(setpoint := 1.0, actual := 0.0, kp := 1.0, ti_s := 0.0, td_s := 0.5,
    cycle_s := 0.1, out_min := -10.0, out_max := 10.0);
ASSERT_TRUE(ABS(pid.out - 1.0) < 0.0001);
pid(actual := 0.5);
ASSERT_TRUE(ABS(pid.out - (-2.0)) < 0.0001);
pid(actual := 0.5);
ASSERT_TRUE(ABS(pid.out - 0.5) < 0.0001);
END_TEST

TEST hidden_bumpless_transfer
VAR pid : FB_PID; END_VAR
pid(setpoint := 1.0, actual := 0.0, kp := 2.0, ti_s := 1.0, td_s := 0.3,
    cycle_s := 0.1, out_min := -10.0, out_max := 10.0, manual := TRUE, manual_value := 5.0);
ASSERT_TRUE(ABS(pid.out - 5.0) < 0.0001);
pid(manual := FALSE);
(* I = 5 - 2 = 3, then + 0.2; no derivative kick on the first automatic call *)
ASSERT_TRUE(ABS(pid.out - 5.2) < 0.0001);
END_TEST

TEST hidden_no_integral_and_zero_cycle
VAR pid : FB_PID; END_VAR
pid(setpoint := 2.0, actual := 0.0, kp := 1.5, ti_s := 0.0, td_s := 0.0,
    cycle_s := 0.1, out_min := -10.0, out_max := 10.0);
pid();
ASSERT_TRUE(ABS(pid.out - 3.0) < 0.0001);
pid(ti_s := 1.0, td_s := 1.0, cycle_s := 0.0);
ASSERT_TRUE(ABS(pid.out - 3.0) < 0.0001);
END_TEST

TEST hidden_manual_clears_saturation
VAR pid : FB_PID; END_VAR
pid(setpoint := 1.0, actual := 0.0, kp := 4.0, ti_s := 0.0, cycle_s := 0.1,
    out_min := -3.0, out_max := 3.0);
ASSERT_TRUE(pid.saturated);
pid(manual := TRUE, manual_value := 1.0);
ASSERT_FALSE(pid.saturated);
END_TEST

TEST hidden_no_kick_after_manual
VAR pid : FB_PID; END_VAR
pid(setpoint := 1.0, actual := 0.0, kp := 1.0, ti_s := 0.0, td_s := 1.0,
    cycle_s := 0.1, out_min := -10.0, out_max := 10.0);
pid(manual := TRUE, manual_value := 0.0);
(* the error changes from 1.0 to 0.5 on the first automatic call: no D *)
pid(manual := FALSE, actual := 0.5);
ASSERT_TRUE(ABS(pid.out - 0.5) < 0.0001);
END_TEST

TEST hidden_derivative_in_antiwindup
VAR pid : FB_PID; END_VAR
pid(setpoint := 5.0, actual := 0.0, kp := 1.0, ti_s := 1.0, td_s := 1.0,
    cycle_s := 0.1, out_min := -10.0, out_max := 5.8);
ASSERT_TRUE(ABS(pid.out - 5.5) < 0.0001);
(* P + I_new = 5.89 is above the limit, but with D = -1 u = 4.89 is not:
   the integral is updated *)
pid(actual := 0.1);
ASSERT_TRUE(ABS(pid.out - 4.89) < 0.0001);
END_TEST

TEST hidden_limit_itself_is_not_saturated
VAR pid : FB_PID; END_VAR
pid(setpoint := 2.0, actual := 0.0, kp := 1.0, ti_s := 0.0, cycle_s := 0.1,
    out_min := -2.0, out_max := 2.0);
ASSERT_TRUE(ABS(pid.out - 2.0) < 0.0001);
ASSERT_FALSE(pid.saturated);
pid(setpoint := -2.0);
ASSERT_FALSE(pid.saturated);
END_TEST
