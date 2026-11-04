(* spec: [types.conversion.vendor]
   expect: warning RP0126
   run: PRG_Main cycles=1
   assert: x = 3
   assert: y = 6 *)
PROGRAM PRG_Main
VAR
    w : DWORD := 5;
    u : UDINT := 3;
    x, y : DWORD;
END_VAR
x := u;
y := w XOR u;
END_PROGRAM
