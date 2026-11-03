(* spec: [types.derived.array]
   expect: error RP0109 *)
PROGRAM PRG_Main
VAR
    a : ARRAY[0..2] OF INT;
END_VAR
a[3] := 1;
END_PROGRAM
