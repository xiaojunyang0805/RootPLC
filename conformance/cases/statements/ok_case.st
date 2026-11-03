(* spec: [statements.case]
   expect: ok
   run: PRG_Main cycles=1
   assert: r = 2 *)
PROGRAM PRG_Main
VAR
    n : INT := 7;
    r : INT;
END_VAR
CASE n OF
    1, 2:
        r := 1;
    3..9:
        r := 2;
ELSE
    r := 0;
END_CASE
END_PROGRAM
