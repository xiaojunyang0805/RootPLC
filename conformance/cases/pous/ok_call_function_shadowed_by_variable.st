(* spec: [pous.call.callee]
   expect: ok
   run: PRG_Main cycles=1
   assert: r.Twice = 8 *)
FUNCTION Twice : INT
VAR_INPUT
    x : INT;
END_VAR
Twice := 2 * x;
END_FUNCTION

TYPE ST_R :
STRUCT
    Twice : INT;   (* a member named like the function *)
END_STRUCT
END_TYPE

PROGRAM PRG_Main
VAR
    r : ST_R;
    Twice : STRING;   (* a variable named like the function *)
END_VAR
r.Twice := Twice(4);   (* calls the function *)
END_PROGRAM
