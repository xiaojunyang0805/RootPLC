(* spec: [types.derived.enum] [types.conversion.implicit]
   expect: error RP0103 *)
TYPE Mode : (Off, Manual, Auto); END_TYPE

PROGRAM PRG_Main
VAR
    m : Mode;
    i : INT;
END_VAR
i := m;
END_PROGRAM
