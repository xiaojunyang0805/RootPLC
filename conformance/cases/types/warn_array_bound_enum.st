(* spec: [variables.constant-names] [scope.vendor-forms]
   expect: warning RP0135
   run: PRG_Main cycles=1
   assert: lo = 1
   assert: hi = 3
   assert: n = 3 *)
TYPE ST_Lanes :
STRUCT
    speed : ARRAY[E_Lane.Nr1..E_Lane.Nr3] OF INT;
END_STRUCT;
END_TYPE

TYPE E_Lane : (Nr1 := 1, Nr2, Nr3); END_TYPE

PROGRAM PRG_Main
VAR
    lanes : ARRAY[E_Lane.Nr1..E_Lane.Nr3] OF INT;
    lanes2 : ST_Lanes;
    lo, hi, n : DINT;
END_VAR
lo := LOWER_BOUND(lanes, 1);
hi := UPPER_BOUND(lanes, 1);
n := UPPER_BOUND(lanes2.speed, 1);
END_PROGRAM
