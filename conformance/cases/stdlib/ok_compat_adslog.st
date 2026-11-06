(* spec: [stdlib.compat.log]
   libraries: Tc2_System
   expect: ok
   run: PRG_Main cycles=2
   assert: res = 0
   assert: count = 2 *)
PROGRAM PRG_Main
VAR
    res : DINT := -1;
    count : DINT;
END_VAR
count := count + 1;
res := ADSLOGSTR(ADSLOG_MSGTYPE_HINT, 'Started %s', 'motor');
res := res + ADSLOGDINT(ADSLOG_MSGTYPE_WARN, 'Cycle %d', count);
res := res + ADSLOGLREAL(ADSLOG_MSGTYPE_ERROR, 'Speed %f', 1.5);
END_PROGRAM
