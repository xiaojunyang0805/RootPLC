TEST hidden_initially_off
VAR uut : PRG_Motor; END_VAR
uut();
ASSERT_FALSE(uut.running);
END_TEST

TEST hidden_stop_resets
VAR uut : PRG_Motor; END_VAR
uut(start := TRUE);
uut(start := FALSE);
uut(stop := TRUE);
ASSERT_FALSE(uut.running);
uut(stop := FALSE);
ASSERT_FALSE(uut.running);
END_TEST

TEST hidden_stop_wins
VAR uut : PRG_Motor; END_VAR
uut(start := TRUE, stop := TRUE);
ASSERT_FALSE(uut.running);
uut(start := TRUE, stop := FALSE);
ASSERT_TRUE(uut.running);
uut(start := TRUE, stop := TRUE);
ASSERT_FALSE(uut.running);
END_TEST
