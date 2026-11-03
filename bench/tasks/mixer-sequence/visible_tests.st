TEST visible_start_fills
VAR uut : PRG_Mixer; END_VAR
uut(start := TRUE);
ASSERT_EQ(1, uut.phase);
ASSERT_TRUE(uut.fill_valve);
END_TEST
