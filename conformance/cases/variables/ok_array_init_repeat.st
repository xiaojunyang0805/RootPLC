(* spec: [variables.initializer]
   expect: ok
   run: PRG_Main cycles=1
   assert: a[0] = 1
   assert: a[1] = 7
   assert: a[3] = 7
   assert: a[4] = 2
   assert: a[5] = 0
   assert: d[2] = 0
   assert: d[3] = 9 *)
PROGRAM PRG_Main
VAR
    a : ARRAY[0..5] OF INT := [1, 3(7), 2];   (* 3(7): three elements of 7 *)
    d : ARRAY[0..3] OF INT := [1, 2(), 9];    (* 2(): two defaults *)
END_VAR
END_PROGRAM
