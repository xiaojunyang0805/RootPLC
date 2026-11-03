(* spec: [lexical.literal.integer] [lexical.literal.underscore] [lexical.literal.sign]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 1000000
   assert: b = 165
   assert: c = 15
   assert: d = 255
   assert: e = -128 *)
PROGRAM PRG_Main
VAR
    a : DINT := 1_000_000;
    b : INT := 2#1010_0101;
    c : INT := 8#17;
    d : DINT := 16#ff;
    e : SINT := -128;
END_VAR

END_PROGRAM
