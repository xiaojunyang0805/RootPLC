(* spec: [stdlib.functions.bounds]
   expect: ok
   run: PRG_Main cycles=1
   assert: s1 = 6
   assert: s2 = 30
   assert: lo = 2
   assert: hi = 4
   assert: x[3] = 0
   assert: m = 20 *)
FUNCTION SumAndClear : DINT
VAR_IN_OUT
    a : ARRAY[*] OF INT;
END_VAR
VAR
    i : DINT;
END_VAR
FOR i := LOWER_BOUND(a, 1) TO UPPER_BOUND(a, 1) DO
    SumAndClear := SumAndClear + a[i];
    a[i] := 0;
END_FOR
END_FUNCTION

FUNCTION MaxOf : INT
VAR_INPUT
    a : ARRAY[*] OF INT;
END_VAR
VAR
    i : DINT;
END_VAR
MaxOf := a[LOWER_BOUND(a, 1)];
FOR i := LOWER_BOUND(a, 1) + 1 TO UPPER_BOUND(a, 1) DO
    MaxOf := MAX(MaxOf, a[i]);
END_FOR
END_FUNCTION

PROGRAM PRG_Main
VAR
    x : ARRAY[2..4] OF INT := [1, 2, 3];
    y : ARRAY[0..1] OF INT := [10, 20];
    s1, s2, lo, hi : DINT;
    m : INT;
END_VAR
m := MaxOf(y);
s1 := SumAndClear(x);
s2 := SumAndClear(y);
lo := LOWER_BOUND(x, 1);
hi := UPPER_BOUND(x, 1);
END_PROGRAM
