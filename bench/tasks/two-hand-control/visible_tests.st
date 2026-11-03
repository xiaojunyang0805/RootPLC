TEST visible_simultaneous_press
VAR uut : FB_TwoHand; END_VAR
uut(left := TRUE, right := TRUE);
ASSERT_TRUE(uut.enable);
END_TEST
