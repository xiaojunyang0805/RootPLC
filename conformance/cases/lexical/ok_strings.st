(* spec: [lexical.literal.string] [lexical.literal.escape]
   expect: ok
   run: PRG_Main cycles=1
   assert: h = 'A' *)
PROGRAM PRG_Main
VAR
    s : STRING := 'it$'s $$5$N';
    w : WSTRING := "say $"hi$"";
    h : STRING := '$41';
END_VAR

END_PROGRAM
