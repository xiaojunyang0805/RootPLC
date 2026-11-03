(* spec: [variables.initializer]
   expect: ok
   run: PRG_Main cycles=1
   assert: pt = T#1S
   assert: n = 7
   assert: d = 3 *)
FUNCTION_BLOCK FB_Count
VAR_INPUT
    k : INT := 3;
END_VAR
VAR_OUTPUT
    Count : INT;
END_VAR
Count := k;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    t : TON := (PT := T#1S);
    a : FB_Count := (k := 7);
    b : FB_Count := ();
    pt : TIME;
    n, d : INT;
END_VAR
a();
b();
pt := t.PT;
n := a.Count;
d := b.Count;
END_PROGRAM
