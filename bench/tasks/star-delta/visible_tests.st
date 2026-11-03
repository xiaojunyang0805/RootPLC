TEST visible_star_first
VAR uut : FB_StarDelta; END_VAR
uut(start := TRUE);
ASSERT_TRUE(uut.main);
ASSERT_TRUE(uut.star);
ASSERT_FALSE(uut.delta);
END_TEST
