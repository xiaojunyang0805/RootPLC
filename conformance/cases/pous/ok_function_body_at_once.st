(* spec: [pous.function]
   expect: warning RP0113
   run: PRG_Main cycles=1
   assert: n = 2 *)
VAR_GLOBAL
    total : INT;
END_VAR

FUNCTION Bump
total := total + 1;
END_FUNCTION

PROGRAM PRG_Main
VAR
    n : INT;
END_VAR
Bump();
Bump();
n := total;
END_PROGRAM
