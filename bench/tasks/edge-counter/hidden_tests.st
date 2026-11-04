TEST hidden_holding_counts_once
VAR uut : FB_PulseCounter; i : INT; END_VAR
FOR i := 1 TO 10 DO
    uut(pulse := TRUE);
END_FOR;
ASSERT_EQ(1, uut.count);
END_TEST

TEST hidden_reset_clears_and_blocks
VAR uut : FB_PulseCounter; END_VAR
uut(pulse := TRUE);
uut(pulse := FALSE);
uut(pulse := TRUE);
uut(pulse := FALSE);
ASSERT_EQ(2, uut.count);
uut(reset := TRUE);
ASSERT_EQ(0, uut.count);
uut(pulse := TRUE, reset := TRUE);
ASSERT_EQ(0, uut.count);
uut(pulse := FALSE, reset := FALSE);
uut(pulse := TRUE);
ASSERT_EQ(1, uut.count);
END_TEST

TEST hidden_many_pulses
VAR uut : FB_PulseCounter; i : INT; END_VAR
FOR i := 1 TO 250 DO
    uut(pulse := TRUE);
    uut(pulse := FALSE);
END_FOR;
ASSERT_EQ(250, uut.count);
END_TEST
