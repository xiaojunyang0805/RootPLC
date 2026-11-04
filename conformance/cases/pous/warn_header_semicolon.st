(* spec: [pous.function-block] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=1
   assert: v = 7 *)
FUNCTION Seven : INT;
Seven := 7;
END_FUNCTION

FUNCTION_BLOCK FB_X
METHOD Get : INT;
VAR_INPUT
    x : INT;
END_VAR
Get := x;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    f : FB_X;
    v : INT;
END_VAR
v := f.Get(x := Seven());
END_PROGRAM
