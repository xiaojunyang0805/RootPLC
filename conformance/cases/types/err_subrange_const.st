(* spec: [types.derived.subrange]
   expect: error RP0105 *)
TYPE Percent : INT (0..100); END_TYPE

PROGRAM PRG_Main
VAR
    p : Percent := 150;
END_VAR

END_PROGRAM
