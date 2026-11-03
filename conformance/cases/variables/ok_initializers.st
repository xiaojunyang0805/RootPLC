(* spec: [variables.initializer]
   expect: ok
   run: PRG_Main cycles=1
   assert: a[2] = 3
   assert: p.y = 2 *)
TYPE Point : STRUCT x : INT; y : INT; END_STRUCT END_TYPE

PROGRAM PRG_Main
VAR
    a : ARRAY[0..2] OF INT := [1, 2, 3];
    p : Point := (x := 1, y := 2);
END_VAR
END_PROGRAM
