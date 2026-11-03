TEST visible_heats_when_cold
VAR uut : FB_Heater; END_VAR
uut(temp := 20, setpoint := 50);
ASSERT_TRUE(uut.heat);
END_TEST
