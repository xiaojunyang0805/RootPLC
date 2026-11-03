TEST hidden_layer_pulse
VAR uut : PRG_Palletizer; i : INT; END_VAR
FOR i := 1 TO 5 DO
    uut(box := TRUE);
    uut(box := FALSE);
END_FOR
uut(box := TRUE);
ASSERT_TRUE(uut.layer_done);
ASSERT_EQ(0, uut.boxes_in_layer);
ASSERT_EQ(1, uut.layers);
uut(box := FALSE);
ASSERT_FALSE(uut.layer_done);
END_TEST

TEST hidden_pallet_and_reset
VAR uut : PRG_Palletizer; i : INT; END_VAR
FOR i := 1 TO 24 DO
    uut(box := TRUE);
    uut(box := FALSE);
END_FOR
ASSERT_TRUE(uut.pallet_done);
ASSERT_EQ(4, uut.layers);
uut(box := TRUE);
uut(box := FALSE);
ASSERT_EQ(0, uut.boxes_in_layer);
ASSERT_EQ(4, uut.layers);
uut(reset := TRUE);
ASSERT_FALSE(uut.pallet_done);
ASSERT_EQ(0, uut.layers);
uut(reset := FALSE, box := TRUE);
ASSERT_EQ(1, uut.boxes_in_layer);
END_TEST
