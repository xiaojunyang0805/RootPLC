(* spec: [config.global-list] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=3
   assert: c = 13
   assert: last = 13 *)
VAR_GLOBAL CONSTANT
    N_MAX : INT := 3;
    N_LAST : INT := N_MAX + 1;
END_VAR
VAR_GLOBAL
    counter : INT := 10;
    buf : ARRAY[1..N_LAST] OF INT;
END_VAR

PROGRAM PRG_Main
VAR
    last, c : INT;
END_VAR
counter := counter + 1;
buf[N_LAST] := counter;
last := buf[4];
c := counter;
END_PROGRAM
