TEST visible_start_stop
VAR uut : PRG_Conveyor; END_VAR
uut(start := TRUE, estop_ok := TRUE, guard_closed := TRUE);
uut(start := FALSE);
ASSERT_TRUE(uut.motor);
uut(stop := TRUE);
ASSERT_FALSE(uut.motor);
END_TEST
