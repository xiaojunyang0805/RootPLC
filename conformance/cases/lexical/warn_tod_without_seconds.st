(* spec: [lexical.literal.date] [scope.vendor-forms]
   expect: warning RP0133
   run: PRG_Main cycles=1
   assert: same = TRUE
   assert: dsame = TRUE *)
PROGRAM PRG_Main
VAR
    a : TOD := TOD#12:00;
    d : DT := DT#2000-01-01-08:30;
    same, dsame : BOOL;
END_VAR
same := a = TOD#12:00:00;
dsame := d = DT#2000-01-01-08:30:00;
END_PROGRAM
