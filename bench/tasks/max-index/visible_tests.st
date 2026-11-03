TEST visible_simple
VAR a : ARRAY[1..8] OF INT := [1, 2, 3, 9, 4, 5, 6, 7]; END_VAR
ASSERT_EQ(4, MaxIndex(a));
END_TEST
