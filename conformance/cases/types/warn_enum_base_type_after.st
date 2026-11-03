(* spec: [types.derived.enum]
   expect: warning RP0115
   run: PRG_Main cycles=1
   assert: n = 10 *)
TYPE E_Mode : (Off := 0, Manual := 5, Auto := 10) UINT; END_TYPE

PROGRAM PRG_Main
VAR
    m : E_Mode := E_Mode#Auto;
    n : INT;
END_VAR
n := TO_INT(m);
END_PROGRAM
