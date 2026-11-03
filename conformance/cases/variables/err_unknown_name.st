(* spec: [variables.resolution]
   expect: error RP0203 *)
PROGRAM PRG_Main
VAR
    x : INT;
END_VAR
x := y + 1;
END_PROGRAM
