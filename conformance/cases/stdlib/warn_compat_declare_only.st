(* spec: [stdlib.compat.declare-only]
   libraries: Tc2_System
   expect: warning RP0120
   run: PRG_Main cycles=1
   assert: res = 0 *)
PROGRAM PRG_Main
VAR
    logNow : BOOL;
    res : DINT;
END_VAR
IF logNow THEN
    res := ADSLOGSTR(ADSLOG_MSGTYPE_HINT, 'Started %s', 'motor');
END_IF;
END_PROGRAM
