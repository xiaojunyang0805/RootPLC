TEST visible_pi_step
VAR pid : FB_PID; i : INT; END_VAR
FOR i := 1 TO 10 DO
    pid(setpoint := 1.0, actual := 0.0, kp := 2.0, ti_s := 1.0, td_s := 0.0,
        cycle_s := 0.1, out_min := -10.0, out_max := 10.0);
END_FOR;
ASSERT_TRUE(ABS(pid.out - 4.0) < 0.0001);
ASSERT_FALSE(pid.saturated);
END_TEST

TEST visible_manual
VAR pid : FB_PID; END_VAR
pid(setpoint := 1.0, actual := 0.0, kp := 2.0, ti_s := 1.0, cycle_s := 0.1,
    out_min := 0.0, out_max := 50.0, manual := TRUE, manual_value := 80.0);
ASSERT_TRUE(ABS(pid.out - 50.0) < 0.0001);
END_TEST
