TEST visible_midpoint
VAR r : REAL; END_VAR
r := ScaleAnalog(raw := 13824, lo := 0.0, hi := 100.0);
ASSERT_TRUE(ABS(r - 50.0) < 0.01);
END_TEST
