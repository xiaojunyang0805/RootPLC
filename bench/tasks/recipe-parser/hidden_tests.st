TEST hidden_empty_entries_skipped
VAR uut : FB_RecipeParser; END_VAR
uut(text := ';;A=1;;B=2;');
ASSERT_EQ(2, uut.count);
ASSERT_EQ(2, uut.values[2]);
ASSERT_FALSE(uut.error);
ASSERT_EQ(0, uut.error_pos);
uut(text := '');
ASSERT_EQ(0, uut.count);
ASSERT_FALSE(uut.error);
END_TEST

TEST hidden_duplicate_key_replaces
VAR uut : FB_RecipeParser; END_VAR
uut(text := 'Speed=1;temp=2;SPEED=7');
ASSERT_EQ(2, uut.count);
ASSERT_TRUE(uut.keys[1] = 'Speed');
ASSERT_EQ(7, uut.values[1]);
ASSERT_EQ(2, uut.values[2]);
END_TEST

TEST hidden_key_rules
VAR uut : FB_RecipeParser; END_VAR
uut(text := 'A=1;9x=2');
ASSERT_TRUE(uut.error);
ASSERT_EQ(5, uut.error_pos);
ASSERT_EQ(1, uut.count);
uut(text := 'abcdefghijklmnopqrst=5');
ASSERT_FALSE(uut.error);
ASSERT_EQ(5, uut.values[1]);
uut(text := 'abcdefghijklmnopqrstu=5');
ASSERT_TRUE(uut.error);
ASSERT_EQ(1, uut.error_pos);
uut(text := 'x1_y=3;a-b=1');
ASSERT_EQ(1, uut.count);
ASSERT_EQ(8, uut.error_pos);
END_TEST

TEST hidden_value_rules
VAR uut : FB_RecipeParser; END_VAR
uut(text := 'A=123456789;B=-987654321');
ASSERT_EQ(123456789, uut.values[1]);
ASSERT_EQ(-987654321, uut.values[2]);
uut(text := 'A=1234567890');
ASSERT_TRUE(uut.error);
uut(text := 'A=;B=1');
ASSERT_TRUE(uut.error);
ASSERT_EQ(1, uut.error_pos);
uut(text := 'A=-');
ASSERT_TRUE(uut.error);
uut(text := 'A=1=2');
ASSERT_TRUE(uut.error);
uut(text := '=5');
ASSERT_TRUE(uut.error);
END_TEST

TEST hidden_spaces_invalid
VAR uut : FB_RecipeParser; END_VAR
uut(text := 'A=1; B=2');
ASSERT_TRUE(uut.error);
ASSERT_EQ(5, uut.error_pos);
ASSERT_EQ(1, uut.count);
uut(text := 'A=1 ');
ASSERT_TRUE(uut.error);
ASSERT_EQ(0, uut.count);
END_TEST

TEST hidden_ninth_key
VAR uut : FB_RecipeParser; END_VAR
uut(text := 'a=1;b=2;c=3;d=4;e=5;f=6;g=7;h=8;A=9;i=10');
ASSERT_TRUE(uut.error);
ASSERT_EQ(8, uut.count);
ASSERT_EQ(9, uut.values[1]);
ASSERT_EQ(37, uut.error_pos);
END_TEST

TEST hidden_outputs_reset_each_call
VAR uut : FB_RecipeParser; END_VAR
uut(text := 'A=1;B=2;C=3');
uut(text := 'Z=4');
ASSERT_EQ(1, uut.count);
ASSERT_TRUE(uut.keys[2] = '');
ASSERT_EQ(0, uut.values[3]);
uut(text := 'Q=x');
ASSERT_EQ(0, uut.count);
ASSERT_TRUE(uut.keys[1] = '');
END_TEST
