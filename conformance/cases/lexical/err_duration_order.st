(* spec: [lexical.literal.duration]
   expect: error RP0011 *)
PROGRAM PRG_Main
VAR
    t : TIME := T#5s1m;
END_VAR

END_PROGRAM
