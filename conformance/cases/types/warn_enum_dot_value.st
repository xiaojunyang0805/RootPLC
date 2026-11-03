(* spec: [types.derived.enum]
   expect: warning RP0122
   run: PRG_Main cycles=1
   assert: n = 10
   assert: same = TRUE
   assert: k = 1 *)
TYPE E_Mode : (Off := 0, Manual := 5, Auto := 10); END_TYPE

NAMESPACE Plant
TYPE E_Valve : (Closed, Open); END_TYPE
END_NAMESPACE

PROGRAM PRG_Main
VAR
    m : E_Mode := E_Mode.Auto;
    v : Plant.E_Valve;
    n, k : INT;
    same : BOOL;
END_VAR
n := TO_INT(m);
same := m = E_Mode#Auto;
v := Plant.E_Valve.Open;
k := TO_INT(v);
END_PROGRAM
