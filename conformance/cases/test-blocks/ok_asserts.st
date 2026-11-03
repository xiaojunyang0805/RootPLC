(* spec: [tests.assert] [pous.test]
   expect: ok *)
FUNCTION Add : INT
VAR_INPUT
    a, b : INT;
END_VAR
Add := a + b;
END_FUNCTION

TEST add_works
VAR
    r : INT;
END_VAR
r := Add(2, 3);
ASSERT_EQ(5, r);
ASSERT_NE(4, r);
ASSERT_TRUE(r > 0);
ASSERT_FALSE(r < 0);
END_TEST
