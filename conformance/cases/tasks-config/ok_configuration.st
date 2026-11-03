(* spec: [config.configuration]
   expect: ok
   run: PRG_Main cycles=2
   assert: n = 2 *)
PROGRAM PRG_Main
VAR
    n : INT;
END_VAR
n := n + 1;
END_PROGRAM

CONFIGURATION Cfg
    VAR_GLOBAL
        mode : INT := 1;
    END_VAR
    RESOURCE Res ON PLC
        TASK Fast(INTERVAL := T#10ms, PRIORITY := 1);
        PROGRAM Main WITH Fast : PRG_Main;
    END_RESOURCE
END_CONFIGURATION
