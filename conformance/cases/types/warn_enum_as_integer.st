(* spec: [types.derived.enum.integer]
   expect: warning RP0129
   run: PRG_Main cycles=1
   assert: n = 2
   assert: plus = 3
   assert: next = Mode#Auto
   assert: same = TRUE
   assert: k = 1
   assert: fromInt = Mode#Manual
   assert: big = TRUE *)
TYPE Mode : (Off, Manual, Auto);
END_TYPE

TYPE Level : (Low, Mid, High);
END_TYPE

{attribute 'strict'}
TYPE StrictMode : (Idle, Busy);
END_TYPE

PROGRAM PRG_Main
VAR
    m : Mode := Mode#Auto;
    n : INT;
    plus : INT;
    next : Mode;
    same : BOOL;
    k : INT;
    fromInt : Mode;
    i : INT := 1;
    s : StrictMode;
    big : BOOL;
END_VAR
n := m;                           (* value as integer *)
plus := Mode#Auto + 1;            (* arithmetic on a non-strict enumeration *)
next := Mode#Manual + 1;          (* integer stored in a non-strict enumeration *)
same := Mode#Auto = Level#High;   (* compared as integers *)
s := StrictMode#Busy;
k := s;                           (* a strict value still reads as an integer *)
big := s > 0;
fromInt := i;
END_PROGRAM
