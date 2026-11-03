(* spec: [lexical.pragma]
   expect: ok *)
PROGRAM PRG_Main
VAR
    {attribute 'hide'}
    x : INT;
END_VAR

END_PROGRAM
