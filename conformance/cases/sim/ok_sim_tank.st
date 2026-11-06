(* spec: [sim.command] [sim.scenario] [sim.run] [sim.trace] [sim.compare] [sim.limits]
   expect: ok *)
(* A level controller and its plant model as two programs sharing global
   variables; crates/rootplc-driver/tests/sim.rs runs a scenario on them
   with rootplc sim. *)
CONFIGURATION Tank
    VAR_GLOBAL
        rLevel : REAL;           (* plant output, % *)
        bPump : BOOL;            (* controller output *)
    END_VAR
    RESOURCE Cpu ON PLC
        TASK Main (INTERVAL := T#100ms, PRIORITY := 1);
        PROGRAM Plant WITH Main : PRG_Plant;
        PROGRAM Control WITH Main : PRG_Main;
    END_RESOURCE
END_CONFIGURATION

PROGRAM PRG_Plant
VAR_EXTERNAL
    rLevel : REAL;
    bPump : BOOL;
END_VAR
VAR
    rInflow : REAL := 2.0;       (* % per second with the pump on *)
    rOutflow : REAL := 0.5;      (* % per second, always *)
    rCycleS : REAL := 0.1;
END_VAR
IF bPump THEN
    rLevel := rLevel + rInflow * rCycleS;
END_IF;
rLevel := MAX(rLevel - rOutflow * rCycleS, 0.0);
END_PROGRAM

PROGRAM PRG_Main
VAR_EXTERNAL
    rLevel : REAL;
    bPump : BOOL;
END_VAR
VAR
    bStart : BOOL;
    bRunning : BOOL;
    rLow : REAL := 40.0;
    rHigh : REAL := 60.0;
    fbStart : R_TRIG;
    nSwitches : INT;
END_VAR
fbStart(CLK := bStart);
IF fbStart.Q THEN
    bRunning := TRUE;
END_IF;
IF bRunning AND rLevel < rLow AND NOT bPump THEN
    bPump := TRUE;
    nSwitches := nSwitches + 1;
ELSIF rLevel > rHigh OR NOT bRunning THEN
    bPump := FALSE;
END_IF;
END_PROGRAM
