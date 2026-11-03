(* spec: [syntax.general]
   expect: error RP0201 *)
PROGRAM PRG_Main
VAR
    x : INT;
END_VAR
x := ;
END_PROGRAM
