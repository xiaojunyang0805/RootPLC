TEST visible_starts_on
VAR uut : FB_Blink; END_VAR
uut(enable := TRUE, period := T#1s);
ASSERT_TRUE(uut.out);
END_TEST
