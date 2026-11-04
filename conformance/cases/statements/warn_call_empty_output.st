(* spec: [statements.call] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=1
   assert: n = 4 *)
FUNCTION_BLOCK FB_Count
VAR_INPUT
    k : INT;
END_VAR
VAR_OUTPUT
    Done : BOOL;
    Count : INT;
END_VAR
Done := TRUE;
Count := k;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    f : FB_Count;
    n : INT;
END_VAR
f(k := 4, Done =>, Count => n);
END_PROGRAM
