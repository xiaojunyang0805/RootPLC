(* spec: [types.conversion.implicit]
   expect: error RP0103 *)
PROGRAM PRG_Main
VAR
    b : BOOL;
    i : INT := 1;
END_VAR
b := i;
END_PROGRAM
