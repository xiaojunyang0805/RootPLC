(* spec: [pous.test]
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 2 *)
FUNCTION TEST : INT
VAR_INPUT
    name : STRING;
END_VAR
TEST := LEN(name);
END_FUNCTION

PROGRAM PRG_Main
VAR
    n : INT;
END_VAR
n := TEST('ab');
END_PROGRAM
