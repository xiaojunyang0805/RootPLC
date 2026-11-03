TEST visible_two_samples
VAR uut : FB_MovingAverage; END_VAR
uut(x := 4.0);
uut(x := 8.0);
ASSERT_TRUE(ABS(uut.avg - 6.0) < 0.001);
END_TEST
