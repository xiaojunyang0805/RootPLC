TEST visible_integrates
VAR uut : FB_Totalizer; i : INT; END_VAR
FOR i := 1 TO 10 DO
    uut(flow := 2.0, cycle_ms := 100, enable := TRUE, batch_size := 1.0);
END_FOR;
ASSERT_TRUE(ABS(uut.total - 2.0) < 0.001);
ASSERT_EQ(2, uut.batches);
END_TEST

TEST visible_reset
VAR uut : FB_Totalizer; END_VAR
uut(flow := 5.0, cycle_ms := 1000, enable := TRUE, batch_size := 2.0);
uut(reset := TRUE);
ASSERT_TRUE(uut.total = 0.0);
ASSERT_EQ(0, uut.batches);
END_TEST
