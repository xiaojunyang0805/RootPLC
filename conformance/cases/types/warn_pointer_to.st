(* spec: [types.reference]
   expect: warning RP0116
   run: PRG_Main cycles=1
   assert: v = 7 *)
PROGRAM PRG_Main
VAR
    x : INT := 7;
    p : POINTER TO INT;
    v : INT;
END_VAR
p := REF(x);
v := p^;
END_PROGRAM
