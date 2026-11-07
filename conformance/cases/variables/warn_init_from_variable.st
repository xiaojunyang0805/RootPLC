(* spec: [variables.initializer.variable] [scope.vendor-forms]
   expect: warning RP0135
   run: PRG_Main cycles=1
   assert: left = 6000
   assert: half = 3000
   assert: early = 0
   assert: fromFun = 12 *)
FUNCTION_BLOCK Tank
VAR_OUTPUT
    early : DINT := later;
    maxMs : DINT := 6000;
    leftMs : DINT := maxMs;
    halfMs : DINT := maxMs / 2;
    later : DINT := 7;
END_VAR
leftMs := leftMs;
END_FUNCTION_BLOCK

FUNCTION Twice : DINT
VAR_INPUT
    x : DINT;
END_VAR
VAR
    base : DINT := 6;
    double : DINT := base * 2;
END_VAR
Twice := double + x * 0;
END_FUNCTION

PROGRAM PRG_Main
VAR
    t : Tank;
    left, half, early, fromFun : DINT;
END_VAR
t();
left := t.leftMs;
half := t.halfMs;
early := t.early;
fromFun := Twice(1);
END_PROGRAM
