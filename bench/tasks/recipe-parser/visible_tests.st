TEST visible_three_entries
VAR uut : FB_RecipeParser; END_VAR
uut(text := 'Speed=1200;Temp=-15;Time_s=90');
ASSERT_EQ(3, uut.count);
ASSERT_TRUE(uut.keys[1] = 'Speed');
ASSERT_EQ(1200, uut.values[1]);
ASSERT_EQ(-15, uut.values[2]);
ASSERT_TRUE(uut.keys[3] = 'Time_s');
ASSERT_FALSE(uut.error);
END_TEST

TEST visible_bad_value
VAR uut : FB_RecipeParser; END_VAR
uut(text := 'A=1;B=x2');
ASSERT_EQ(1, uut.count);
ASSERT_TRUE(uut.error);
ASSERT_EQ(5, uut.error_pos);
END_TEST
