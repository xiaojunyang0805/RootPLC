(* spec: [statements.assignment.chain]
   expect: warning RP0125
   run: PRG_Main cycles=1
   assert: a = 7
   assert: b = 7
   assert: c = 7 *)
PROGRAM PRG_Main
VAR
    a, b, c : INT;
END_VAR
a := b := c := 7;
END_PROGRAM
