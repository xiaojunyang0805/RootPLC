TEST visible_disabled_shows_red_only
VAR uut : PRG_TrafficLight; END_VAR
uut(enable := FALSE);
ASSERT_TRUE(uut.red);
ASSERT_FALSE(uut.yellow OR uut.green);
END_TEST
