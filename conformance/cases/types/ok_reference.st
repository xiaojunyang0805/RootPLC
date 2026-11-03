(* spec: [types.reference]
   expect: ok
   run: PRG_Main cycles=1
   assert: x = 9 *)
PROGRAM PRG_Main
VAR
    x : INT := 5;
    r : REF_TO INT;
END_VAR
r := REF(x);
r^ := 9;
END_PROGRAM
