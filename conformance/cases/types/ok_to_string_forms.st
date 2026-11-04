(* spec: [types.conversion.explicit]
   expect: ok
   run: PRG_Main cycles=1
   assert: r1 = '0.1'
   assert: r2 = '-3.402823E38'
   assert: r3 = '1.0'
   assert: l1 = '123456789.0'
   assert: l2 = '1E-7'
   assert: t1 = 'T#49d17h2m47s295ms'
   assert: t2 = 'T#1s500ms'
   assert: t3 = 'T#0ms'
   assert: t4 = 'LT#1ms500us' *)
PROGRAM PRG_Main
VAR
    r1, r2, r3, l1, l2 : STRING;
    t1, t2, t3, t4 : STRING;
END_VAR
r1 := REAL_TO_STRING(REAL#0.1);
r2 := REAL_TO_STRING(REAL#-3.402823E38);
r3 := REAL_TO_STRING(REAL#1.0);
l1 := LREAL_TO_STRING(123456789.0);
l2 := LREAL_TO_STRING(1.0E-7);
t1 := TIME_TO_STRING(T#49d17h2m47s295ms);
t2 := TIME_TO_STRING(T#1500ms);
t3 := TIME_TO_STRING(T#0ms);
t4 := LTIME_TO_STRING(LTIME#1500us);
END_PROGRAM
