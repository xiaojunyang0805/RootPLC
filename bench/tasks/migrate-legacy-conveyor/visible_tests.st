TEST visible_start_runs_at_setpoint
VAR uut : PRG_Conveyor; END_VAR
uut(start := TRUE, estop_ok := TRUE, speed_setpoint := 60);
uut(start := FALSE);
ASSERT_TRUE(uut.motor);
ASSERT_TRUE(uut.speed_cmd = 60);
END_TEST
