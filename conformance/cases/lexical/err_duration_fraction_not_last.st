(* spec: [lexical.literal.duration]
   expect: error RP0011 *)
PROGRAM PRG_Main
VAR
    t : TIME := T#1.5s20ms;
END_VAR

END_PROGRAM
