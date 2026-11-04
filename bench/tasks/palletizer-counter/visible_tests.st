TEST visible_counts_boxes
VAR uut : PRG_Palletizer; i : INT; END_VAR
FOR i := 1 TO 3 DO
    uut(box := TRUE);
    uut(box := FALSE);
END_FOR;
ASSERT_EQ(3, uut.boxes_in_layer);
END_TEST
