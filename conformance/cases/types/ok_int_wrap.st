(* spec: [types.int.overflow]
   expect: ok
   run: PRG_Main cycles=1
   assert: x = -128
   assert: u = 255 *)
PROGRAM PRG_Main
VAR
    x : SINT := 127;
    u : USINT := 0;
END_VAR
x := x + 1;
u := u - 1;
END_PROGRAM
