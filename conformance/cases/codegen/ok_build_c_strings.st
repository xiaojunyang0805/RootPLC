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
   assert: count = 2
   assert: r1 = '0.1'
   assert: r2 = '1E-5'
   assert: r3 = '1.5E16'
   assert: r4 = '100.0'
   assert: r5 = '-0.00025'
   assert: r6 = '0.0001'
   assert: d1 = 'D#2026-11-07'
   assert: t1 = 'TOD#12:30:15.25'
   assert: dt1 = 'DT#2026-11-07-08:09:10' *)
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
    r1, r2, r3, r4, r5, r6 : STRING;
    d1, t1, dt1 : STRING;
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
r1 := REAL_TO_STRING(0.1);
r2 := REAL_TO_STRING(1.0E-5);
r3 := REAL_TO_STRING(1.5E16);
r4 := REAL_TO_STRING(100.0);
r5 := LREAL_TO_STRING(-2.5E-4);
r6 := LREAL_TO_STRING(1.0E-4);
d1 := DATE_TO_STRING(D#2026-11-07);
t1 := TOD_TO_STRING(TOD#12:30:15.25);
dt1 := DT_TO_STRING(DT#2026-11-07-08:09:10);
END_PROGRAM
