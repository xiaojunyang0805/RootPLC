(* spec: [types.reference]
   expect: warning RP0117
   run: PRG_Main cycles=1
   assert: v = 9 *)
PROGRAM PRG_Main
VAR
    x : INT := 4;
    r : REF_TO INT;
    v : INT;
END_VAR
r := ADR(x);
r^ := 9;
v := x;
END_PROGRAM
