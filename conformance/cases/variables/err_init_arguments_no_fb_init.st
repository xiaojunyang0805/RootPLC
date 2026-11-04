(* spec: [variables.init-arguments]
   expect: error RP0203 RP0119 *)
FUNCTION_BLOCK FB_Buffer
VAR_INPUT
    size : INT;
END_VAR
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    b : FB_Buffer(size := 10);
END_VAR
END_PROGRAM
