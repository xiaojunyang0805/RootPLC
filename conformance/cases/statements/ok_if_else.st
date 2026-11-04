(* spec: [statements.if]
   expect: ok
   run: PRG_Main cycles=1
   assert: y = 2 *)
PROGRAM PRG_Main
VAR
    x : INT := 5;
    y : INT;
END_VAR
IF x > 3 THEN
    y := 2;
ELSE
    y := 1;
END_IF;
END_PROGRAM
