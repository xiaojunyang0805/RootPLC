(* spec: [config.program-instance]
   expect: error RP0203 *)
PROGRAM PRG_Main
END_PROGRAM

CONFIGURATION Cfg
    TASK Fast(INTERVAL := T#10ms);
    PROGRAM Main WITH Fast : PRG_Missing;
END_CONFIGURATION
