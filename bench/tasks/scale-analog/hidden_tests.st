TEST hidden_range_and_clamp
VAR r : REAL; END_VAR
r := ScaleAnalog(raw := 0, lo := 4.0, hi := 20.0);
ASSERT_TRUE(ABS(r - 4.0) < 0.01);
r := ScaleAnalog(raw := 27648, lo := 4.0, hi := 20.0);
ASSERT_TRUE(ABS(r - 20.0) < 0.01);
r := ScaleAnalog(raw := 6912, lo := 4.0, hi := 20.0);
ASSERT_TRUE(ABS(r - 8.0) < 0.01);
r := ScaleAnalog(raw := -500, lo := 4.0, hi := 20.0);
ASSERT_TRUE(ABS(r - 4.0) < 0.01);
r := ScaleAnalog(raw := 32000, lo := 4.0, hi := 20.0);
ASSERT_TRUE(ABS(r - 20.0) < 0.01);
r := ScaleAnalog(raw := 13824, lo := -50.0, hi := 50.0);
ASSERT_TRUE(ABS(r) < 0.01);
r := ScaleAnalog(raw := 1, lo := 0.0, hi := 27648.0);
ASSERT_TRUE(ABS(r - 1.0) < 0.01);
END_TEST
