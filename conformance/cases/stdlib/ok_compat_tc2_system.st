(* spec: [stdlib.compat]
   libraries: Tc2_System, TwinCAT_BuiltIns
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 255
   assert: r > 6.28 AND r < 6.29
   assert: ready *)
TYPE ST_Flags : STRUCT
    running : BIT;
END_STRUCT; END_TYPE

PROGRAM PRG_Main
VAR
    s : T_MaxString := 'motor';
    n : UDINT;
    r : LREAL;
    f : ST_Flags;
    ready : BOOL;
END_VAR
n := MAX_STRING_LENGTH;
r := Tc2_System.PI * 2.0;
f.running := ADSLOG_MSGTYPE_HINT = 16#01;
ready := f.running;
END_PROGRAM
