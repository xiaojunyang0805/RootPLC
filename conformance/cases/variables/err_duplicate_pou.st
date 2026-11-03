(* spec: [variables.unique]
   expect: error RP0204 *)
TYPE Motor : STRUCT running : BOOL; END_STRUCT END_TYPE

FUNCTION_BLOCK MOTOR
VAR_INPUT
    start : BOOL;
END_VAR
END_FUNCTION_BLOCK
