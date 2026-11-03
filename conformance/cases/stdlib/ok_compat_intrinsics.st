(* spec: [stdlib.compat.intrinsics]
   libraries: TwinCAT_BuiltIns
   expect: warning RP0006
   run: PRG_Main cycles=3
   assert: who = 'FB_Who'
   assert: t >= T#0MS *)
FUNCTION_BLOCK FB_Who
VAR_OUTPUT
    name : STRING;
END_VAR
name := __POUNAME();
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    f : FB_Who;
    who : STRING;
    t : TIME;
END_VAR
f();
who := f.name;
t := TIME();
END_PROGRAM
