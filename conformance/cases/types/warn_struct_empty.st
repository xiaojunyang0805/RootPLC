(* spec: [types.derived.struct] [scope.vendor-forms]
   expect: warning RP0134 *)
TYPE ST_Placeholder :
STRUCT
END_STRUCT;
END_TYPE

PROGRAM PRG_Main
VAR
    s : ST_Placeholder;
END_VAR
END_PROGRAM
