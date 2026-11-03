(* spec: [lexical.source.charset] [lexical.punctuation]
   expect: error RP0005 *)
PROGRAM PRG_Main
VAR
    x : INT;
END_VAR
x := 1 @ 2;
END_PROGRAM
