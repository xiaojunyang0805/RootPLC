(* spec: [pous.oop.this]
   expect: ok
   run: PRG_Main cycles=1
   assert: v = 5 *)
FUNCTION_BLOCK FB_Box
VAR
    hidden : INT;
END_VAR
METHOD Set
VAR_INPUT
    x : INT;
END_VAR
THIS^.hidden := x;
END_METHOD
METHOD Get : INT
Get := THIS^.hidden;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    b : FB_Box;
    v : INT;
END_VAR
b.Set(x := 5);
v := b.Get();
END_PROGRAM
