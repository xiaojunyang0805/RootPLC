TEST hidden_hysteresis
VAR uut : PRG_Tank; END_VAR
uut(level := 50.0);
ASSERT_FALSE(uut.pump);
uut(level := 15.0);
ASSERT_TRUE(uut.pump);
uut(level := 50.0);
ASSERT_TRUE(uut.pump);
uut(level := 79.9);
ASSERT_TRUE(uut.pump);
uut(level := 85.0);
ASSERT_FALSE(uut.pump);
uut(level := 50.0);
ASSERT_FALSE(uut.pump);
uut(level := 20.0);
ASSERT_FALSE(uut.pump);
END_TEST
