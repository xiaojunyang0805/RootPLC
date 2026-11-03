(* spec: [stdlib.compat.sizeof]
   libraries: TwinCAT_BuiltIns
   expect: error RP0121 *)
FUNCTION_BLOCK FB_X
VAR
    n : INT;
END_VAR
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    fb : FB_X;
    n : UDINT;
END_VAR
n := SIZEOF(fb);
END_PROGRAM
