TEST hidden_estop_latches_fault
VAR uut : PRG_Conveyor; END_VAR
uut(start := TRUE, estop_ok := TRUE, guard_closed := TRUE);
uut(start := FALSE);
uut(estop_ok := FALSE);
ASSERT_FALSE(uut.motor);
ASSERT_TRUE(uut.fault);
uut(reset := TRUE);
ASSERT_TRUE(uut.fault);
uut(reset := FALSE, estop_ok := TRUE);
ASSERT_TRUE(uut.fault);
uut(start := TRUE);
ASSERT_FALSE(uut.motor);
uut(start := FALSE, reset := TRUE);
ASSERT_FALSE(uut.fault);
ASSERT_FALSE(uut.motor);
uut(reset := FALSE, start := TRUE);
ASSERT_TRUE(uut.motor);
END_TEST

TEST hidden_guard_stops_without_fault
VAR uut : PRG_Conveyor; END_VAR
uut(start := TRUE, estop_ok := TRUE, guard_closed := TRUE);
uut(start := FALSE);
uut(guard_closed := FALSE);
ASSERT_FALSE(uut.motor);
ASSERT_FALSE(uut.fault);
uut(start := TRUE);
ASSERT_FALSE(uut.motor);
uut(start := FALSE, guard_closed := TRUE);
ASSERT_FALSE(uut.motor);
uut(start := TRUE);
ASSERT_TRUE(uut.motor);
END_TEST
