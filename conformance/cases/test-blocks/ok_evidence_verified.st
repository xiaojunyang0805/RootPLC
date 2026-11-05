(* spec: [tests.evidence] [tests.mutation]
   expect: ok
   mutate: killed=3 viable=3
   evidence: verified *)
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

TEST latch_sets_holds_and_stops
VAR
    l : FB_Latch;
END_VAR
l(start := TRUE, stop := FALSE);
ASSERT_TRUE(l.running);
l(start := FALSE, stop := FALSE);
ASSERT_TRUE(l.running);
l(start := TRUE, stop := TRUE);
ASSERT_FALSE(l.running);
END_TEST
