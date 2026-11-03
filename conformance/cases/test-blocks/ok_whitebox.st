(* spec: [tests.whitebox] [tests.runner]
   expect: ok *)
FUNCTION_BLOCK FB_Count
VAR_INPUT
    pulse : BOOL;
END_VAR
VAR
    hidden : INT;
END_VAR
IF pulse THEN
    hidden := hidden + 1;
END_IF
END_FUNCTION_BLOCK

TEST internal_state_is_visible
VAR
    uut : FB_Count;
END_VAR
uut(pulse := TRUE);
uut(pulse := TRUE);
ASSERT_EQ(2, uut.hidden);
END_TEST
