TEST hidden_window_of_four
VAR uut : FB_MovingAverage; END_VAR
uut(x := 4.0);
ASSERT_TRUE(ABS(uut.avg - 4.0) < 0.001);
uut(x := 8.0);
uut(x := 12.0);
uut(x := 16.0);
ASSERT_TRUE(ABS(uut.avg - 10.0) < 0.001);
uut(x := 20.0);
ASSERT_TRUE(ABS(uut.avg - 14.0) < 0.001);
uut(x := 0.0);
uut(x := 0.0);
uut(x := 0.0);
uut(x := 0.0);
ASSERT_TRUE(ABS(uut.avg) < 0.001);
END_TEST
