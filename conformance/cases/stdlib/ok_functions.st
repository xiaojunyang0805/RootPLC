(* spec: [stdlib.conversions] [stdlib.functions]
   expect: ok
   run: PRG_Main cycles=1
   assert: d = 2
   assert: i = 3
   assert: w = 16#0F00
   assert: n = 4 *)
PROGRAM PRG_Main
VAR
    i : INT := -7;
    d : DINT;
    r : LREAL := 2.7;
    w : WORD := 16#00F0;
    s : STRING;
    n : INT;
END_VAR
d := INT_TO_DINT(ABS(i));
d := TRUNC(r);
i := LIMIT(0, i, 100);
i := MAX(i, 3);
w := SHL(w, 4);
s := CONCAT('ab', 'cd');
n := LEN(s);
r := TO_LREAL(n) + SQRT(r);
END_PROGRAM
