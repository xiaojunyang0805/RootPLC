(* spec: [lexical.literal.typed] [lexical.literal.bool]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 5
   assert: b = 255
   assert: c = TRUE
   assert: d = TRUE
   assert: e = 1.5 *)
PROGRAM PRG_Main
VAR
    a : INT := INT#5;
    b : BYTE := BYTE#16#FF;
    c : BOOL := BOOL#1;
    d : BOOL := TRUE;
    e : REAL := REAL#1.5;
END_VAR

END_PROGRAM
