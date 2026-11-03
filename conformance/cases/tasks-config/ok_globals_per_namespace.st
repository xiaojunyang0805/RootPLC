(* spec: [config.global-list]
   expect: ok
   run: PRG_Main cycles=1
   assert: a = 1
   assert: b = 2 *)
NAMESPACE GVL_A
VAR_GLOBAL
    station : INT := 1;
END_VAR
END_NAMESPACE

NAMESPACE GVL_B
VAR_GLOBAL
    station : INT := 2;
END_VAR
END_NAMESPACE

PROGRAM PRG_Main
VAR
    a, b : INT;
END_VAR
a := GVL_A.station;
b := GVL_B.station;
END_PROGRAM
