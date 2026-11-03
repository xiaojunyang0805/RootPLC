TEST hidden_limits
VAR r : REAL; END_VAR
r := P_Control(setpoint := 100.0, actual := 0.0, kp := 5.0, out_min := 0.0, out_max := 100.0);
ASSERT_TRUE(ABS(r - 100.0) < 0.001);
r := P_Control(setpoint := 10.0, actual := 30.0, kp := 1.0, out_min := 0.0, out_max := 100.0);
ASSERT_TRUE(ABS(r) < 0.001);
r := P_Control(setpoint := 10.0, actual := 30.0, kp := 1.0, out_min := -50.0, out_max := 50.0);
ASSERT_TRUE(ABS(r + 20.0) < 0.001);
r := P_Control(setpoint := 3.0, actual := 2.0, kp := 0.5, out_min := -1.0, out_max := 1.0);
ASSERT_TRUE(ABS(r - 0.5) < 0.001);
END_TEST
