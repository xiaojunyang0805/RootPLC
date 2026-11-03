(* spec: [syntax.recovery]
   expect: error RP0301 RP0201 *)
PROGRAM PRG_Main
VAR
    x, y : INT;
END_VAR
x := 1
y := * 2;
END_PROGRAM
