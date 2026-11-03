(* spec: [types.int.division]
   expect: error RP0101 *)
PROGRAM PRG_Main
VAR
    x : INT;
END_VAR
x := 5 / 0;
END_PROGRAM
