(* spec: [lexical.longest-match] [lexical.punctuation] [types.derived.array]
   expect: ok
   run: PRG_Main cycles=1
   assert: b = TRUE
   assert: a[10] = 1 *)
PROGRAM PRG_Main
VAR
    a : ARRAY[1..10] OF INT;
    x : INT := 1;
    y : INT := 2;
    b : BOOL;
END_VAR
b := x<=y;
a[10] := x**2;
END_PROGRAM
