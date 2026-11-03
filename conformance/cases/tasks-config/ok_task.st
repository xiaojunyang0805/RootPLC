(* spec: [config.task]
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 1 *)
PROGRAM PRG_Main
VAR
    n : INT;
END_VAR
n := n + 1;
END_PROGRAM

CONFIGURATION Cfg
    RESOURCE Res ON PLC
        TASK Slow(INTERVAL := T#100ms, PRIORITY := 5);
        TASK Fast(INTERVAL := T#1ms);
        PROGRAM Main WITH Fast : PRG_Main;
        PROGRAM Other WITH Slow : PRG_Main;
    END_RESOURCE
END_CONFIGURATION
