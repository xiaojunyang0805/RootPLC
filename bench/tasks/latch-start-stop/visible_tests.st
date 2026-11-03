TEST visible_start_latches
VAR uut : PRG_Motor; END_VAR
uut(start := TRUE);
uut(start := FALSE);
ASSERT_TRUE(uut.running);
END_TEST
