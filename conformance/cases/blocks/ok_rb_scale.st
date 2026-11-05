(* spec: [blocks.library] [blocks.fault] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suite of RB_Scale (card blocks/cards/F01.SCALE.md). *)
TEST scale_maps_linearly
VAR s : RB_Scale; END_VAR
s(Raw := 13824.0, RawMin := 0.0, RawMax := 27648.0, EngMin := 0.0, EngMax := 10.0);
ASSERT_TRUE(ABS(s.Value - 5.0) < 0.0001);
s(Raw := 4.0, RawMin := 4.0, RawMax := 20.0, EngMin := -50.0, EngMax := 150.0);
ASSERT_TRUE(ABS(s.Value + 50.0) < 0.0001);
s(Raw := 12.0, RawMin := 4.0, RawMax := 20.0, EngMin := -50.0, EngMax := 150.0);
ASSERT_TRUE(ABS(s.Value - 50.0) < 0.0001);
(* a falling characteristic *)
s(Raw := 0.0, RawMin := 0.0, RawMax := 100.0, EngMin := 10.0, EngMax := 0.0);
ASSERT_TRUE(ABS(s.Value - 10.0) < 0.0001);
ASSERT_FALSE(s.Error);
END_TEST

TEST scale_clamps_within_the_margin
VAR s : RB_Scale; END_VAR
s(Raw := 21.0, RawMin := 4.0, RawMax := 20.0, EngMin := 0.0, EngMax := 100.0, Margin := 2.0);
ASSERT_FALSE(s.Error);
ASSERT_TRUE(ABS(s.Value - 100.0) < 0.0001);
s(Raw := 3.0, RawMin := 4.0, RawMax := 20.0, EngMin := 0.0, EngMax := 100.0, Margin := 2.0);
ASSERT_TRUE(ABS(s.Value) < 0.0001);
s(Raw := 21.0, RawMin := 4.0, RawMax := 20.0, EngMin := 0.0, EngMax := 100.0, Margin := 2.0, Clamp := FALSE);
ASSERT_TRUE(ABS(s.Value - 106.25) < 0.0001);
(* a falling characteristic clamps too *)
s(Raw := 21.0, RawMin := 4.0, RawMax := 20.0, EngMin := 100.0, EngMax := 0.0, Margin := 2.0, Clamp := TRUE);
ASSERT_TRUE(ABS(s.Value) < 0.0001);
s(Raw := 3.0, RawMin := 4.0, RawMax := 20.0, EngMin := 100.0, EngMax := 0.0, Margin := 2.0);
ASSERT_TRUE(ABS(s.Value - 100.0) < 0.0001);
END_TEST

TEST scale_wire_break_latches_and_holds_the_last_value
VAR s : RB_Scale; END_VAR
s(Raw := 12.0, RawMin := 4.0, RawMax := 20.0, EngMin := 0.0, EngMax := 100.0, Margin := 0.5);
ASSERT_TRUE(ABS(s.Value - 50.0) < 0.0001);
s(Raw := 3.4, RawMin := 4.0, RawMax := 20.0, EngMin := 0.0, EngMax := 100.0, Margin := 0.5);
ASSERT_TRUE(s.Error);
ASSERT_EQ(UDINT#2, s.ErrorID);
ASSERT_TRUE(ABS(s.Value - 50.0) < 0.0001);
(* back in range: still latched, still the last valid value *)
s(Raw := 16.0, RawMin := 4.0, RawMax := 20.0, EngMin := 0.0, EngMax := 100.0, Margin := 0.5);
ASSERT_TRUE(s.Error);
ASSERT_TRUE(ABS(s.Value - 50.0) < 0.0001);
s(Raw := 16.0, RawMin := 4.0, RawMax := 20.0, EngMin := 0.0, EngMax := 100.0, Margin := 0.5, Reset := TRUE);
ASSERT_FALSE(s.Error);
ASSERT_EQ(UDINT#0, s.ErrorID);
ASSERT_TRUE(ABS(s.Value - 75.0) < 0.0001);
END_TEST

TEST scale_over_range_and_invalid_range
VAR s : RB_Scale; t : RB_Scale; END_VAR
s(Raw := 20.6, RawMin := 4.0, RawMax := 20.0, Margin := 0.5);
ASSERT_TRUE(s.Error);
ASSERT_EQ(UDINT#3, s.ErrorID);
s(Raw := 20.4, RawMin := 4.0, RawMax := 20.0, Margin := 0.5, Reset := TRUE);
ASSERT_FALSE(s.Error);
t(Raw := 5.0, RawMin := 4.0, RawMax := 4.0);
ASSERT_TRUE(t.Error);
ASSERT_EQ(UDINT#1, t.ErrorID);
(* the range may be given in either order *)
s(Raw := 4.2, RawMin := 20.0, RawMax := 4.0, EngMin := 0.0, EngMax := 100.0, Reset := FALSE);
ASSERT_FALSE(s.Error);
ASSERT_TRUE(ABS(s.Value - 98.75) < 0.0001);
END_TEST

TEST scale_limits_of_the_margin_are_valid
VAR s : RB_Scale; END_VAR
s(Raw := 20.5, RawMin := 4.0, RawMax := 20.0, Margin := 0.5);
ASSERT_FALSE(s.Error);
s(Raw := 3.5, RawMin := 4.0, RawMax := 20.0, Margin := 0.5);
ASSERT_FALSE(s.Error);
END_TEST
