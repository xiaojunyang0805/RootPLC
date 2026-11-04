(* spec: [stdlib.string.length]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 120
   assert: b = 160
   assert: c = 10
   assert: d = 125 *)
PROGRAM PRG_Main
VAR
    s60 : STRING[60] := '012345678901234567890123456789012345678901234567890123456789';
    long : STRING[300];
    short : STRING[10];
    a, b, c, d : INT;
END_VAR
long := CONCAT(s60, s60);
a := LEN(long);
long := CONCAT(long, CONCAT(s60, LEFT(s60, 40)));
a := LEN(CONCAT(s60, s60));
b := LEN(LEFT(long, 160));
short := CONCAT(s60, 'x');
c := LEN(short);
d := LEN(INSERT(long, 'abcde', 3)) - 100;
END_PROGRAM
