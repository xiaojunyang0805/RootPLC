TEST hidden_behaviour
VAR uut : FB_Heater; END_VAR
uut(temp := 20, setpoint := 50);
ASSERT_TRUE(uut.level = 30);
uut(temp := 60, setpoint := 50);
ASSERT_FALSE(uut.heat);
ASSERT_TRUE(uut.level = 0);
uut(temp := 50, setpoint := 50);
ASSERT_FALSE(uut.heat);
uut(temp := -200, setpoint := 50);
ASSERT_TRUE(uut.heat);
ASSERT_TRUE(uut.level = 100);
END_TEST
