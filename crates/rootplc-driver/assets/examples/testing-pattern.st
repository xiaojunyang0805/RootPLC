(* title: How to write TEST blocks with virtual time
   tags: test, TEST, ASSERT, ADVANCE, virtual time, white-box
   description: The testing pattern: instantiate the program or block, call it once per cycle, move virtual time with ADVANCE, and assert on inputs, outputs or internal variables. *)
FUNCTION_BLOCK EX_Toggle
VAR_INPUT
    enable : BOOL;
END_VAR
VAR_OUTPUT
    lamp : BOOL;
END_VAR
VAR
    t : TON;
END_VAR
t(IN := enable AND NOT t.Q, PT := T#500ms);
IF t.Q THEN
    lamp := NOT lamp;
END_IF
IF NOT enable THEN
    lamp := FALSE;
END_IF
END_FUNCTION_BLOCK

TEST ex_toggle_after_half_second
VAR uut : EX_Toggle; i : INT; END_VAR
FOR i := 1 TO 6 DO uut(enable := TRUE); ADVANCE(T#100ms); END_FOR
ASSERT_TRUE(uut.lamp);
uut(enable := FALSE);
ASSERT_FALSE(uut.lamp);
END_TEST
