TEST visible_counts_three_pulses
VAR uut : FB_PulseCounter; i : INT; END_VAR
FOR i := 1 TO 3 DO
    uut(pulse := TRUE);
    uut(pulse := FALSE);
END_FOR;
ASSERT_EQ(3, uut.count);
END_TEST
