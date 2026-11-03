(* spec: [stdlib.compat]
   libraries: Tc2_System, TwinCAT_BuiltIns
   expect: warning RP0006 RP0122
   run: PRG_Main cycles=1
   assert: older = -1
   assert: same = 0
   assert: taskNo = 1
   assert: idx = 1
   assert: cls = TRUE
   assert: port = 851 *)
PROGRAM PRG_Main
VAR
    v : ST_LibVersion := (iMajor := 3, iMinor := 4, iBuild := 1, iRevision := 0);
    older, same, idx : DINT;
    taskNo : BYTE;
    getIdx : GETCURTASKINDEX;
    tc : __SYSTEM.TYPE_CLASS;
    cls : BOOL;
    addr : ST_AmsAddr;
    port : UINT;
    first : BOOL;
END_VAR
older := F_CmpLibVersion(v, 3, 5, 0, 0);
same := F_CmpLibVersion(v, 3, 4, 1, 0);
getIdx();
taskNo := getIdx.index;
idx := GETCURTASKINDEXEX();
first := TwinCAT_SystemInfoVarList._TaskInfo[idx].FirstCycle;
tc := __SYSTEM.TYPE_CLASS.TYPE_LREAL;
cls := TO_DWORD(tc) = 15;
addr.port := 851;
port := addr.port;
END_PROGRAM
