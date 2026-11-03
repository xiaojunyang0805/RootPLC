(* spec: [types.derived.array]
   expect: error RP0108 *)
PROGRAM PRG_Main
VAR
    a : ARRAY[5..1] OF INT;
END_VAR

END_PROGRAM
