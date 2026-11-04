(* spec: [stdlib.compat.taskinfo]
   libraries: TwinCAT_BuiltIns, Tc2_System
   expect: ok *)
PROGRAM PRG_Main
VAR
    cycleMs : UDINT;
END_VAR
cycleMs := _TaskInfo[GETCURTASKINDEXEX()].CycleTime / 10000;
END_PROGRAM
