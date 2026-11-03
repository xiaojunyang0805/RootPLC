(* spec: [pous.test]
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 4 *)
FUNCTION Twice : INT
VAR_INPUT
    x : INT;
END_VAR
VAR
    Test : INT;
END_VAR
Test := 2 * x;
Twice := Test;
END_FUNCTION

PROGRAM PRG_Main
VAR
    n : INT;
END_VAR
n := Twice(x := 2);
END_PROGRAM
