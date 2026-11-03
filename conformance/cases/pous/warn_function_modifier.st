(* spec: [pous.oop.modifiers]
   expect: warning RP0124
   run: PRG_Main cycles=1
   assert: a = 6
   assert: b = 4.0 *)
FUNCTION INTERNAL F_Triple : INT
VAR_INPUT
    x : INT;
END_VAR
F_Triple := x * 3;
END_FUNCTION

FUNCTION OVERRIDE : REAL
VAR_INPUT
    x : REAL;
END_VAR
OVERRIDE := x * 2.0;
END_FUNCTION

PROGRAM PRG_Main
VAR
    a : INT;
    b : REAL;
END_VAR
a := F_Triple(2);
b := OVERRIDE(2.0);
END_PROGRAM
