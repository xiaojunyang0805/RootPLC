TEST hidden_ties_and_edges
VAR
    a : ARRAY[1..8] OF INT := [3, 9, 2, 9, 1, 0, -5, 4];
    b : ARRAY[1..8] OF INT := [-7, -3, -9, -3, -8, -10, -4, -5];
    c : ARRAY[1..8] OF INT := [0, 0, 0, 0, 0, 0, 0, 5];
    d : ARRAY[1..8] OF INT := [32767, 1, 2, 3, 4, 5, 6, 7];
END_VAR
ASSERT_EQ(2, MaxIndex(a));
ASSERT_EQ(2, MaxIndex(b));
ASSERT_EQ(8, MaxIndex(c));
ASSERT_EQ(1, MaxIndex(d));
END_TEST
