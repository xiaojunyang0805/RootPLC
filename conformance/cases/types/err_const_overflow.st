(* spec: [types.int.overflow]
   expect: error RP0101 *)
PROGRAM PRG_Main
VAR
    x : LINT := 9223372036854775807 + 1;
END_VAR

END_PROGRAM
