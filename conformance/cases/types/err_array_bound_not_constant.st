(* spec: [variables.constant-names]
   expect: error RP0108 *)
PROGRAM PRG_Main
VAR
    n : INT := 4;
    buffer : ARRAY[0..n] OF INT;
END_VAR
END_PROGRAM
