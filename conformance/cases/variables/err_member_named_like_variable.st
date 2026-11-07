(* spec: [variables.unique]
   expect: error RP0204 *)
FUNCTION_BLOCK Controller
VAR
    run : BOOL;
END_VAR
METHOD Run
run := TRUE;
END_METHOD
END_FUNCTION_BLOCK
