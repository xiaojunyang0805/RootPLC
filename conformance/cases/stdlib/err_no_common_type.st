(* spec: [stdlib.functions]
   expect: error RP0103 *)
PROGRAM PRG_Main
VAR
    i : INT;
    b : BOOL;
END_VAR
i := MAX(i, b);
END_PROGRAM
