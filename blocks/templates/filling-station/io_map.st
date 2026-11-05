(* The filling station on a controller: located I/O bound to the template
   (spec/14-runtime.md). Adapt the addresses to the board's I/O modules.
   Run: rootplc runtime blocks/templates/filling-station --library RootBlocks
        --program PLC_PRG --modbus 5502 *)
PROGRAM PLC_PRG
VAR
    (* digital inputs *)
    btnAuto       AT %IX0.0 : BOOL;
    btnManual     AT %IX0.1 : BOOL;
    btnOff        AT %IX0.2 : BOOL;
    btnStart      AT %IX0.3 : BOOL;
    btnStop       AT %IX0.4 : BOOL;
    btnReset      AT %IX0.5 : BOOL;
    estopOk       AT %IX0.6 : BOOL;
    highLevel     AT %IX0.7 : BOOL;
    lowLevel      AT %IX1.0 : BOOL;
    inletOpen     AT %IX1.1 : BOOL;
    inletClosed   AT %IX1.2 : BOOL;
    pumpRunning   AT %IX1.3 : BOOL;
    pumpOverload  AT %IX1.4 : BOOL;
    containerIn   AT %IX1.5 : BOOL;
    (* analog input *)
    levelRaw      AT %IW2 : INT;
    (* manual commands from the HMI (Modbus holding register 0) *)
    hmiManual     AT %MW0 : WORD;
    (* outputs *)
    inletValve    AT %QX0.0 : BOOL;
    pump          AT %QX0.1 : BOOL;
    lampRunning   AT %QX0.2 : BOOL;
    lampFault     AT %QX0.3 : BOOL;
    lampAlarm     AT %QX0.4 : BOOL;
    levelPercent  AT %QW2 : INT;    (* level in 0.1 % for the HMI *)
    filledCount   AT %QW4 : UINT;
    station       : FB_FillingStation;
END_VAR
station(ReqAuto := btnAuto, ReqManual := btnManual, ReqOff := btnOff,
        StartBtn := btnStart, StopBtn := btnStop, ResetBtn := btnReset,
        ManInlet := (hmiManual AND WORD#1) <> WORD#0,
        ManPump := (hmiManual AND WORD#2) <> WORD#0,
        EStopOk := estopOk, LevelRaw := INT_TO_REAL(levelRaw),
        HighLevelSw := highLevel, LowLevelSw := lowLevel,
        InletOpenFb := inletOpen, InletClosedFb := inletClosed,
        PumpRunningFb := pumpRunning, PumpOverload := pumpOverload,
        ContainerPresent := containerIn);
inletValve := station.InletValve;
pump := station.Pump;
lampRunning := station.LampRunning;
lampFault := station.LampFault;
lampAlarm := station.LampAlarm;
levelPercent := REAL_TO_INT(station.Level * 10.0);
filledCount := UDINT_TO_UINT(station.Filled);
END_PROGRAM
