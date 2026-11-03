(* spec: [pous.oop.override]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 9
   assert: b = 9
   assert: c = 0 *)
FUNCTION_BLOCK FB_Shape
METHOD Area : INT
Area := 0;
END_METHOD
METHOD Describe : INT
Describe := Area();
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Square EXTENDS FB_Shape
VAR
    side : INT := 3;
END_VAR
METHOD OVERRIDE Area : INT
Area := side * side;
END_METHOD
METHOD Base : INT
Base := SUPER^.Area();
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    sq : FB_Square;
    a, b, c : INT;
END_VAR
a := sq.Area();
b := sq.Describe();
c := sq.Base();
END_PROGRAM
