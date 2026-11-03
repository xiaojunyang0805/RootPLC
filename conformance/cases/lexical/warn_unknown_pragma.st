(* spec: [lexical.pragma]
   expect: warning RP0013 *)
PROGRAM PRG_Main
VAR
    {no_such_pragma 1}
    x : INT;
END_VAR

END_PROGRAM
