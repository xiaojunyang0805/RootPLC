(* spec: [config.var-config]
   expect: ok *)
PROGRAM PRG_Main
VAR
    start : BOOL;
END_VAR
END_PROGRAM

CONFIGURATION Cfg
    VAR_CONFIG
        Main.start AT %IX0.0 : BOOL;
    END_VAR
    RESOURCE Res ON PLC
        TASK Fast(INTERVAL := T#10ms);
        PROGRAM Main WITH Fast : PRG_Main;
    END_RESOURCE
END_CONFIGURATION
