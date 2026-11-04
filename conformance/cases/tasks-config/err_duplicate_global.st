(* spec: [config.global-list]
   expect: error RP0204 *)
CONFIGURATION Cfg
    VAR_GLOBAL
        level : INT;
        level : REAL;
    END_VAR
    RESOURCE Res ON PLC
        TASK Main (INTERVAL := T#10ms, PRIORITY := 1);
        PROGRAM Inst WITH Main : PRG_Main;
    END_RESOURCE
END_CONFIGURATION

PROGRAM PRG_Main
END_PROGRAM
