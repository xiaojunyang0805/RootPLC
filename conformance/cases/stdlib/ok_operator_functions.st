(* spec: [stdlib.functions.operators]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 10
   assert: s = 3
   assert: m = 24
   assert: q = 2
   assert: r = 1
   assert: up = TRUE
   assert: neq = FALSE
   assert: t = T#1500ms *)
PROGRAM PRG_Main
VAR
    a, s, m, q, r : INT;
    up, neq : BOOL;
    t : TIME;
END_VAR
a := ADD(1, 2, 3, 4);
s := SUB(IN1 := 5, IN2 := 2);
m := MUL(2, 3, 4);
q := DIV(7, 3);
r := MOD(7, 3);
up := GT(5, 3, 1) AND LE(1, 1, 2);
neq := NE(4, 4);
t := ADD(T#1S, T#500MS);
END_PROGRAM
