(* spec: [tests.assert]
   expect: error RP0103 *)
TEST bad_assert
VAR
    i : INT := 1;
END_VAR
ASSERT_TRUE(i);
END_TEST
