(* spec: [pous.test]
   expect: ok *)
FUNCTION_BLOCK FB_Latch
VAR_INPUT
    set, reset : BOOL;
END_VAR
VAR_OUTPUT
    q : BOOL;
END_VAR
q := (set OR q) AND NOT reset;
END_FUNCTION_BLOCK

TEST latch_sets
VAR
    uut : FB_Latch;
END_VAR
uut(set := TRUE);
ASSERT_TRUE(uut.q);
END_TEST
