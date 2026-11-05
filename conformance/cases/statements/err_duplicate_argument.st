(* spec: [statements.call]
   expect: error RP0302 *)
FUNCTION_BLOCK FB_Lamp
VAR_INPUT
    on : BOOL;
END_VAR
END_FUNCTION_BLOCK

PROGRAM P
VAR
    lamp : FB_Lamp;
END_VAR
lamp(on := TRUE, ON := FALSE);
END_PROGRAM
