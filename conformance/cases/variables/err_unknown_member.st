(* spec: [variables.resolution]
   expect: error RP0203 *)
PROGRAM PRG_Main
VAR
    tmr : TON;
    b : BOOL;
END_VAR
b := tmr.QQ;
END_PROGRAM
