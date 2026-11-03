(* spec: [types.int.division]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = -3
   assert: b = -1
   assert: c = 1 *)
PROGRAM PRG_Main
VAR
    a : INT;
    b : INT;
    c : INT;
END_VAR
a := -7 / 2;
b := -7 MOD 2;
c := 7 MOD -2;
END_PROGRAM
