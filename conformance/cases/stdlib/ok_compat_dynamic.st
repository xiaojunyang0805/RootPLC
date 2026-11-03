(* spec: [stdlib.compat.dynamic]
   libraries: TwinCAT_BuiltIns
   expect: warning RP0006
   run: PRG_Main cycles=1
   assert: a = 42
   assert: b = 7
   assert: gone = TRUE *)
FUNCTION_BLOCK FB_Node
VAR_INPUT
    v : INT;
END_VAR
METHOD Get : INT
Get := v;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    p : REF_TO INT;
    f : REF_TO FB_Node;
    a, b : INT;
    gone : BOOL;
END_VAR
p := __NEW(INT);
p^ := 41;
a := p^ + 1;
f := __NEW(FB_Node);
f^.v := 7;
b := f^.Get();
__DELETE(p);
__DELETE(f);
gone := p = NULL AND f = NULL;
END_PROGRAM
