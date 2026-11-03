(* spec: [types.derived.enum]
   expect: error RP0106 *)
TYPE Mode : (Off, Manual, Auto); END_TYPE

TYPE Valve : (Closed, Auto); END_TYPE

PROGRAM PRG_Main
VAR
    m : Mode;
END_VAR
m := Auto;
END_PROGRAM
