(* spec: [variables.resolution] [variables.initializer.check]
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 5 *)
TYPE Pt : STRUCT x : INT; y : INT; END_STRUCT END_TYPE
TYPE Color : (Red, Green); END_TYPE

FUNCTION Twice : INT
VAR_INPUT
    v : INT;
END_VAR
Twice := v * 2;
END_FUNCTION

PROGRAM PRG_Main
VAR
    p : Pt := (x := 1);
    c : Color := Green;
    k : ARRAY[1..3] OF INT := [1, 2, 3];
    n : INT;
END_VAR
n := Twice(p.x) + k[3];
END_PROGRAM
