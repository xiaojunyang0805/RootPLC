(* title: Interlock: permissives and trips
   tags: interlock, safety, permissive, trip, emergency stop, guard
   description: A drive may start only when all permissives are true; any trip stops it at once and it needs a new start. The common safety-interlock pattern. *)
FUNCTION_BLOCK EX_Interlock
VAR_INPUT
    start, stop : BOOL;
    permissive_ok, trip : BOOL;
END_VAR
VAR_OUTPUT
    run : BOOL;
END_VAR
IF stop OR trip OR NOT permissive_ok THEN
    run := FALSE;
ELSIF start THEN
    run := TRUE;
END_IF;
END_FUNCTION_BLOCK

TEST ex_trip_wins
VAR uut : EX_Interlock; END_VAR
uut(start := TRUE, permissive_ok := TRUE);
ASSERT_TRUE(uut.run);
uut(start := TRUE, trip := TRUE);
ASSERT_FALSE(uut.run);
uut(start := FALSE, trip := FALSE);
ASSERT_FALSE(uut.run);
END_TEST
