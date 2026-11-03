(* spec: [statements.for]
   expect: ok
   run: PRG_Main cycles=1
   assert: sum = 10 *)
PROGRAM PRG_Main
VAR
    idx : ARRAY[1..2] OF INT;
    sum : INT;
END_VAR
FOR idx[1] := 1 TO 4 DO
    sum := sum + idx[1];
END_FOR
END_PROGRAM
