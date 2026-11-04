(* spec: [lexical.literal.duration]
   expect: warning RP0128
   run: PRG_Main cycles=1
   assert: t = T#150m *)
PROGRAM PRG_Main
VAR
    t : TIME := T#1h90m;
END_VAR

END_PROGRAM
