(* spec: [stdlib.compat.declare-only]
   libraries: Tc2_System
   expect: warning RP0120
   run: PRG_Main cycles=1
   assert: now = 0 *)
PROGRAM PRG_Main
VAR
    readClock : BOOL;
    now : ULINT;
END_VAR
IF readClock THEN
    now := F_GetSystemTime();
END_IF;
END_PROGRAM
