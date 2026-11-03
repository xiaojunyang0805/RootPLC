(* spec: [tests.whitebox] [variables.resolution]
   expect: error RP0203 *)
FUNCTION_BLOCK FB_Count
VAR
    hidden : INT;
END_VAR
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    c : FB_Count;
    n : INT;
END_VAR
n := c.hidden;
END_PROGRAM
