TEST visible_proportional
VAR r : REAL; END_VAR
r := P_Control(setpoint := 50.0, actual := 40.0, kp := 2.0, out_min := 0.0, out_max := 100.0);
ASSERT_TRUE(ABS(r - 20.0) < 0.001);
END_TEST
