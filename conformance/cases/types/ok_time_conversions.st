(* spec: [types.conversion.explicit] [types.conversion.implicit]
   expect: ok
   run: PRG_Main cycles=1
   assert: toL = LT#3ms
   assert: toT = T#1ms
   assert: viaTo = T#10ms
   assert: widened = LT#250ms
   assert: initL = LT#2s
   assert: atLdt = LDT#2026-01-01-10:00:00
   assert: atDt = DT#2026-01-01-10:00:00
   assert: atLtod = LTOD#12:30:00
   assert: gt = TRUE
   assert: eq = TRUE
   assert: later = TRUE
   assert: biggest = LT#2ms
   assert: ns = 1000000 *)
PROGRAM PRG_Main
VAR
    t : TIME := T#250ms;
    initL : LTIME := T#2s;
    toL, widened, biggest : LTIME;
    toT, viaTo : TIME;
    atLdt : LDT;
    atDt : DT;
    atLtod : LTOD;
    gt, eq, later : BOOL;
    ns : ULINT;
END_VAR
toL := TIME_TO_LTIME(T#3ms);
toT := LTIME_TO_TIME(LT#1500us);
viaTo := TO_TIME(TO_LTIME(UDINT#100000 * 100));
widened := t;
atLdt := DT#2026-01-01-10:00:00;
atDt := TO_DT(LDT#2026-01-01-10:00:00);
atLtod := TOD#12:30:00;
gt := T#2ms > LT#1ms;
eq := T#2ms = LT#2ms;
later := DT#2026-01-01-00:00:00 > LDT#2025-01-01-00:00:00;
biggest := MAX(T#2ms, LT#1ms);
ns := LTIME_TO_ULINT(T#1ms);
END_PROGRAM
