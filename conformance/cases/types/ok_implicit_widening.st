(* spec: [types.conversion.implicit]
   expect: ok
   run: PRG_Main cycles=1
   assert: i = -5
   assert: d = -5.0
   assert: w = 15 *)
PROGRAM PRG_Main
VAR
    s : SINT := -5;
    i : INT;
    d : LREAL;
    b : BYTE := 16#0F;
    w : WORD;
END_VAR
i := s;
d := i;
w := b;
END_PROGRAM
