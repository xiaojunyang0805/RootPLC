(* spec: [types.derived.array]
   expect: ok
   run: PRG_Main cycles=1
   assert: a[2] = 7
   assert: a[0] = 0
   assert: m[2, 2] = TRUE *)
PROGRAM PRG_Main
VAR
    a : ARRAY[0..2] OF INT;
    m : ARRAY[1..2, 1..2] OF BOOL;
END_VAR
a[2] := 7;
m[2, 2] := TRUE;
END_PROGRAM
