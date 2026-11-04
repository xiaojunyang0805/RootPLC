(* spec: [types.derived.enum]
   expect: error RP0106 *)
TYPE Mode : (Off, Manual, Auto); END_TYPE

TYPE Valve : (Closed, Auto); END_TYPE

PROGRAM PRG_Main
VAR
    i : INT;
END_VAR
i := TO_INT(Auto);   (* no expected enumeration: Mode#Auto or Valve#Auto? *)
END_PROGRAM
