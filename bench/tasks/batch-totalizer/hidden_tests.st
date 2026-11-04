TEST hidden_small_volumes_on_large_total
VAR uut : FB_Totalizer; i : INT; END_VAR
uut(preset := TRUE, preset_value := 1000000.0);
FOR i := 1 TO 10000 DO
    (* 0.01 l/s for 100 ms: 1 ml per call, 10 l in all *)
    uut(preset := FALSE, flow := 0.01, cycle_ms := 100, enable := TRUE, batch_size := 0.0);
END_FOR;
ASSERT_TRUE(ABS(uut.total - 1000010.0) < 0.1);
ASSERT_TRUE(ABS(uut.remainder - 10.0) < 0.01);
END_TEST

TEST hidden_several_batches_in_one_call
VAR uut : FB_Totalizer; END_VAR
uut(flow := 7.5, cycle_ms := 1000, enable := TRUE, batch_size := 2.0);
ASSERT_EQ(3, uut.batches);
ASSERT_TRUE(ABS(uut.remainder - 1.5) < 0.001);
uut(flow := 0.5, cycle_ms := 1000, enable := TRUE, batch_size := 2.0);
ASSERT_EQ(4, uut.batches);
ASSERT_TRUE(ABS(uut.remainder) < 0.001);
END_TEST

TEST hidden_negative_flow_and_disable
VAR uut : FB_Totalizer; END_VAR
uut(flow := 3.0, cycle_ms := 1000, enable := TRUE, batch_size := 10.0);
uut(flow := -5.0, cycle_ms := 1000, enable := TRUE, batch_size := 10.0);
ASSERT_TRUE(ABS(uut.total - 3.0) < 0.001);
uut(flow := 3.0, cycle_ms := 1000, enable := FALSE, batch_size := 10.0);
ASSERT_TRUE(ABS(uut.total - 3.0) < 0.001);
ASSERT_TRUE(ABS(uut.remainder - 3.0) < 0.001);
END_TEST

TEST hidden_preset_keeps_batches
VAR uut : FB_Totalizer; END_VAR
uut(flow := 5.0, cycle_ms := 1000, enable := TRUE, batch_size := 2.0);
uut(preset := TRUE, preset_value := 100.0, flow := 5.0, cycle_ms := 1000, enable := TRUE, batch_size := 2.0);
ASSERT_TRUE(ABS(uut.total - 100.0) < 0.001);
ASSERT_EQ(2, uut.batches);
ASSERT_TRUE(ABS(uut.remainder - 1.0) < 0.001);
uut(preset := FALSE, flow := 1.0, cycle_ms := 1000, enable := TRUE, batch_size := 2.0);
ASSERT_TRUE(ABS(uut.total - 101.0) < 0.001);
ASSERT_EQ(3, uut.batches);
END_TEST

TEST hidden_reset_has_priority
VAR uut : FB_Totalizer; END_VAR
uut(flow := 5.0, cycle_ms := 1000, enable := TRUE, batch_size := 2.0);
uut(reset := TRUE, preset := TRUE, preset_value := 50.0, flow := 5.0, cycle_ms := 1000, enable := TRUE, batch_size := 2.0);
ASSERT_TRUE(uut.total = 0.0);
ASSERT_TRUE(uut.remainder = 0.0);
ASSERT_EQ(0, uut.batches);
END_TEST

TEST hidden_no_batches_without_size
VAR uut : FB_Totalizer; END_VAR
uut(flow := 4.0, cycle_ms := 1000, enable := TRUE, batch_size := -1.0);
uut(flow := 4.0, cycle_ms := 1000, enable := TRUE, batch_size := 0.0);
ASSERT_EQ(0, uut.batches);
ASSERT_TRUE(ABS(uut.remainder - 8.0) < 0.001);
END_TEST
