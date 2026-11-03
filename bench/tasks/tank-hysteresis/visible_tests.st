TEST visible_low_level_starts_pump
VAR uut : PRG_Tank; END_VAR
uut(level := 10.0);
ASSERT_TRUE(uut.pump);
END_TEST
