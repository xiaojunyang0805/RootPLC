(* spec: [statements.call]
   expect: error RP0302 *)
FUNCTION_BLOCK FB_Lamp
VAR_INPUT
    lit : BOOL;
END_VAR
END_FUNCTION_BLOCK

PROGRAM P
VAR
    lamp : FB_Lamp;
END_VAR
lamp(lit := TRUE, LIT := FALSE);
END_PROGRAM
