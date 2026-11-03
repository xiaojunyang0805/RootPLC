(* spec: [types.literal.untyped]
   expect: ok
   run: PRG_Main cycles=1
   assert: u = 255
   assert: r = 3.0 *)
PROGRAM PRG_Main
VAR
    u : USINT := 255;
    r : REAL := 3;
END_VAR

END_PROGRAM
