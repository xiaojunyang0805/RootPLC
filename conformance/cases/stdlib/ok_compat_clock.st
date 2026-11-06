(* spec: [stdlib.compat.clock]
   libraries: Tc2_System
   expect: ok
   run: PRG_Main cycles=2
   assert: first = ULINT#134116992000000000
   assert: now = first *)
(* The virtual time of day starts at 2026-01-01 00:00:00 UTC (a file time
   in 100 ns units); the conformance runner does not advance the clock. *)
PROGRAM PRG_Main
VAR
    first : ULINT;
    now : ULINT;
END_VAR
IF first = 0 THEN
    first := F_GetSystemTime();
END_IF;
now := F_GetSystemTime();
END_PROGRAM
