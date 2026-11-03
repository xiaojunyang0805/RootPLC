(* spec: [types.conversion.implicit]
   expect: error RP0103 *)
PROGRAM PRG_Main
VAR
    si : SINT;
    i : INT := 1;
END_VAR
si := i;
END_PROGRAM
