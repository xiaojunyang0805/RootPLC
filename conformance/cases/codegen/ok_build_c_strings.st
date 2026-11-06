(* spec: [build.c.semantics] [build.c.strings] [build.c.subset]
   expect: ok
   run: PRG_Main cycles=2
   assert: short = 'abcde'
   assert: joined = 'ab-cd-ef'
   assert: n = 8
   assert: pos = 3
   assert: none = 0
   assert: empty_at = 1
   assert: l = 'ab'
   assert: r = 'ef'
   assert: m = 'cd'
   assert: m0 = 'ab'
   assert: ins = 'XYab-cd-ef'
   assert: ins_end = 'ab-cd-efXY'
   assert: del = 'ab-ef'
   assert: rep = 'ab-ZZZ-ef'
   assert: num = -42
   assert: bad = 0
   assert: neg = '-17'
   assert: dur = 'T#1m30s250ms'
   assert: zero = 'T#0ms'
   assert: yes = 'TRUE'
   assert: less
   assert: count = 2 *)
(* String functions at their edges, for the C back end; the driver test
   compares every variable with the VM. *)
PROGRAM PRG_Main
VAR
    short : STRING[5];
    joined : STRING;
    n : INT;
    pos : INT;
    none : INT;
    empty_at : INT;
    l, r, m, m0 : STRING;
    ins, ins_end, del, rep : STRING;
    num : INT;
    bad : INT;
    neg : STRING;
    dur : STRING;
    zero : STRING;
    yes : STRING;
    less : BOOL;
    count : INT;
END_VAR
count := count + 1;
short := CONCAT('abcd', 'efgh');
joined := CONCAT('ab', '-cd', '-ef');
n := LEN(joined);
pos := FIND(joined, '-');
none := FIND(joined, 'zz');
empty_at := FIND(joined, '');
l := LEFT(joined, 2);
r := RIGHT(joined, 2);
m := MID(joined, 2, 4);
m0 := MID(joined, 2, 0);
ins := INSERT(joined, 'XY', 0);
ins_end := INSERT(joined, 'XY', 99);
del := DELETE(joined, 3, 3);
rep := REPLACE(joined, 'ZZZ', 2, 4);
num := STRING_TO_INT('  -42 ');
bad := STRING_TO_INT('4x2');
neg := INT_TO_STRING(-17);
dur := TIME_TO_STRING(T#90s250ms);
zero := TIME_TO_STRING(T#0s);
yes := BOOL_TO_STRING(TRUE);
less := 'abc' < 'abd' AND 'ab' < 'abc' AND NOT ('b' < 'abc');
END_PROGRAM
