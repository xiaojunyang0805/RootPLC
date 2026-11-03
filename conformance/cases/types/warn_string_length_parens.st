(* spec: [types.derived.string]
   expect: warning RP0112
   run: PRG_Main cycles=1
   assert: n = 3 *)
PROGRAM PRG_Main
VAR
    s : STRING(3) := 'abc';
    w : WSTRING(10);
    t : STRING := 'abcdef';
    n : INT;
END_VAR
s := t;
n := LEN(s);
END_PROGRAM
