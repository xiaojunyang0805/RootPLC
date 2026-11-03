(* spec: [types.reference.alias]
   expect: warning RP0118 RP0006
   run: PRG_Main cycles=1
   assert: x = 12
   assert: v = 12
   assert: valid
   assert: NOT before *)
PROGRAM PRG_Main
VAR
    x : INT := 2;
    r : REFERENCE TO INT;
    v : INT;
    valid, before : BOOL;
END_VAR
before := __ISVALIDREF(r);
r REF= x;
valid := __ISVALIDREF(r);
r := r + 10;
v := r;
END_PROGRAM
