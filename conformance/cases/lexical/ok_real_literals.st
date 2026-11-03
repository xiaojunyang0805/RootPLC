(* spec: [lexical.literal.real]
   expect: ok
   run: PRG_Main cycles=1
   assert: r = 1500.0
   assert: s = 0.25
   assert: t = 0.01 *)
PROGRAM PRG_Main
VAR
    r : LREAL := 1.5E3;
    s : REAL := 0.25;
    t : LREAL := 1.0e-2;
END_VAR

END_PROGRAM
