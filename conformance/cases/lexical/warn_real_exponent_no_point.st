(* spec: [lexical.literal.real]
   expect: warning RP0017
   run: PRG_Main cycles=1
   assert: x = 1000.0
   assert: y > 0.0 AND y < 0.000002 *)
PROGRAM PRG_Main
VAR
    x : LREAL := 1E3;
    y : LREAL := 1E-6;
END_VAR

END_PROGRAM
