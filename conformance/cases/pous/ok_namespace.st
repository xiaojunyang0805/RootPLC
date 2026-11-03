(* spec: [pous.namespace]
   expect: ok
   run: PRG_Main cycles=1
   assert: v = 4 *)
NAMESPACE Plant.Utils
FUNCTION Twice : INT
VAR_INPUT
    x : INT;
END_VAR
Twice := 2 * x;
END_FUNCTION
END_NAMESPACE

USING Plant.Utils;

PROGRAM PRG_Main
VAR
    v : INT;
END_VAR
v := Twice(x := 2);
END_PROGRAM
