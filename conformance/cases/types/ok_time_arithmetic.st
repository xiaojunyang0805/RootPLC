(* spec: [types.time.arith]
   expect: ok
   run: PRG_Main cycles=1
   assert: t1 = TOD#08:30:00
   assert: t2 = TOD#23:30:00
   assert: d1 = DT#2026-11-04-12:01:30
   assert: d2 = DT#2026-11-04-11:59:00
   assert: dur1 = T#90000ms
   assert: dur2 = T#86400000ms
   assert: dur3 = T#3600000ms
   assert: lt = LTOD#00:00:01 *)
PROGRAM PRG_Main
VAR
    t1, t2 : TOD;
    d1, d2 : DT;
    dur1, dur2, dur3 : TIME;
    lt : LTOD;
END_VAR
t1 := TOD#08:00:00 + T#30M;
t2 := TOD#00:30:00 - T#1H;                        (* wraps around midnight *)
d1 := DT#2026-11-04-12:00:00 + T#1M30S500MS;      (* whole seconds *)
d2 := DT#2026-11-04-12:00:00 - T#1M;
dur1 := DT#2026-11-04-12:01:30 - DT#2026-11-04-12:00:00;
dur2 := D#2026-11-05 - D#2026-11-04;
dur3 := TOD#13:00:00 - TOD#12:00:00;
lt := LTOD#23:59:59 + LT#2S;
END_PROGRAM
