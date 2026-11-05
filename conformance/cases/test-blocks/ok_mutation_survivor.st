(* spec: [tests.mutation]
   expect: ok
   mutate: killed=2 viable=3 *)
FUNCTION_BLOCK FB_Latch
VAR_INPUT
    start : BOOL;
    stop : BOOL;
END_VAR
VAR_OUTPUT
    running : BOOL;
END_VAR
running := (start OR running) AND NOT stop;
END_FUNCTION_BLOCK

(* This test never checks stop, so replacing AND by OR survives. *)
TEST latch_sets
VAR
    l : FB_Latch;
END_VAR
l(start := TRUE, stop := FALSE);
ASSERT_TRUE(l.running);
END_TEST
