(* spec: [types.conversion.explicit]
   expect: ok
   run: PRG_Main cycles=1
   assert: sDt = 'DT#2017-04-04-12:42:42'
   assert: sD = 'D#1999-12-31'
   assert: sTod = 'TOD#08:05:03.25'
   assert: sB = 'TRUE'
   assert: sI = '-42' *)
PROGRAM PRG_Main
VAR
    sDt, sD, sTod, sB, sI : STRING;
END_VAR
sDt := DT_TO_STRING(DT#2017-04-04-12:42:42);
sD := DATE_TO_STRING(D#1999-12-31);
sTod := TOD_TO_STRING(TOD#08:05:03.25);
sB := BOOL_TO_STRING(TRUE);
sI := INT_TO_STRING(-42);
END_PROGRAM
