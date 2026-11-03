(* spec: [lexical.literal.escape]
   expect: error RP0010 *)
PROGRAM PRG_Main
VAR
    s : STRING := 'a$Qb';
END_VAR

END_PROGRAM
