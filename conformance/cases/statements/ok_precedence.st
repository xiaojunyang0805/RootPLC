(* spec: [statements.expression.precedence] [statements.expression.access] [syntax.lossless]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 50
   assert: b = TRUE
   assert: c = TRUE
   assert: d = 4
   assert: arr[1, 1] = 50
   assert: p.x = 5 *)
TYPE Point : STRUCT x : INT; END_STRUCT END_TYPE

PROGRAM PRG_Main
VAR
    a : INT;
    b, c : BOOL;
    d : INT;
    arr : ARRAY[0..1, 0..1] OF INT;
    p : Point;
    r : REF_TO Point;
END_VAR
a := 2 + 3 * 4 ** 2;      // 50
b := NOT FALSE OR FALSE;  (* TRUE *)
c := 1 + 2 = 3;
d := -2 ** 2;             /* 4 */
arr[1, 1] := a;
r := REF(p);
r^.x := 5;
END_PROGRAM
