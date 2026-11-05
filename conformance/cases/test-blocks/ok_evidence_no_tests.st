(* spec: [tests.evidence]
   expect: ok
   evidence: not verified *)
(* A program without TEST blocks compiles, but nothing has been verified. *)
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
