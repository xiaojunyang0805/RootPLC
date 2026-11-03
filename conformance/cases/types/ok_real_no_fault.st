(* spec: [types.real]
   expect: ok
   run: PRG_Main cycles=1
   assert: big = TRUE *)
PROGRAM PRG_Main
VAR
    r : LREAL := 1.0;
    big : BOOL;
END_VAR
r := r / 0.0;
big := r > 1.0E308;
END_PROGRAM
