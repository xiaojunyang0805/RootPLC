(* spec: [types.conversion.implicit]
   expect: error RP0103 *)
PROGRAM PRG_Main
VAR
    r : REAL;
    d : DINT;
END_VAR
r := d;
END_PROGRAM
