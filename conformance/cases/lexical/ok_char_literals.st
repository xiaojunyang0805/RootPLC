(* spec: [lexical.literal.char]
   expect: ok
   run: PRG_Main cycles=1
   assert: c = CHAR#'a' *)
PROGRAM PRG_Main
VAR
    c : CHAR := CHAR#'a';
    w : WCHAR := WCHAR#"b";
END_VAR

END_PROGRAM
