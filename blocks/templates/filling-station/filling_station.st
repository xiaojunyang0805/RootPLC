(* L4 template: filling station (blocks/templates/filling-station/README.md).
   Containers are filled with a timed dose from a buffer tank; the tank's
   level is held by an inlet valve. Built only from RootBlocks blocks
   (--library RootBlocks). No I/O inside: io_map.st binds it to the board. *)
FUNCTION_BLOCK FB_FillingStation
VAR_INPUT
    (* operator *)
    ReqOff           : BOOL;
    ReqManual        : BOOL;
    ReqAuto          : BOOL;
    StartBtn         : BOOL;
    StopBtn          : BOOL;
    ResetBtn         : BOOL;            (* also acknowledges alarms *)
    ManInlet         : BOOL;            (* manual commands *)
    ManPump          : BOOL;
    EStopOk          : BOOL := TRUE;    (* status from the safety relay *)
    (* plant *)
    LevelRaw         : REAL;            (* level transmitter, 0 .. 27648 *)
    HighLevelSw      : BOOL;            (* TRUE: tank level high *)
    LowLevelSw       : BOOL;            (* TRUE: enough liquid for the pump *)
    InletOpenFb      : BOOL;
    InletClosedFb    : BOOL;
    PumpRunningFb    : BOOL;
    PumpOverload     : BOOL;
    ContainerPresent : BOOL;
    (* parameters *)
    LevelSP          : REAL := 60.0;    (* % *)
    LevelBand        : REAL := 20.0;    (* % *)
    DoseTime         : TIME := T#3s;
    BatchSize        : UDINT := 10;
END_VAR
VAR_OUTPUT
    InletValve  : BOOL;
    Pump        : BOOL;
    LampRunning : BOOL;
    LampFault   : BOOL;
    LampAlarm   : BOOL;
    Level       : REAL;                 (* % *)
    Filled      : UDINT;                (* containers in this batch *)
    State       : RB_MACHINE_STATE;
    Mode        : RB_MODE;
END_VAR
VAR
    modes     : RB_ModeManager;
    machine   : RB_MachineState;
    levelIn   : RB_Scale;
    levelPv   : RB_FilterPT1;
    levelCtl  : RB_OnOff;
    inlet     : RB_ValveOnOff;
    pumpDev   : RB_Pump;
    container : RB_Debounce;
    chain     : RB_StepChain;
    highAlarm : RB_Alarm;
    count     : RB_Counter;
    fault     : BOOL;
    running   : BOOL;
    aborted   : BOOL;
    proceed   : BOOL;
END_VAR

(* devices and measurements report faults; any fault aborts the machine *)
fault := inlet.Error OR pumpDev.Error OR levelIn.Error;
modes(ReqOff := ReqOff, ReqManual := ReqManual, ReqAuto := ReqAuto,
      EStopOk := EStopOk, Fault := fault);
Mode := modes.Mode;

(* the reset button clears an abort, otherwise it resets the machine *)
aborted := machine.State = RB_MACHINE_STATE#Aborted;
machine(Reset := ResetBtn AND NOT aborted, Clear := ResetBtn AND aborted,
        Start := StartBtn AND Mode = RB_MODE#Auto,
        Stop := StopBtn OR Mode <> RB_MODE#Auto OR count.Done,
        Abort := NOT EStopOk OR fault,
        ResetDone := NOT fault, StartDone := TRUE,
        StopDone := chain.StepNo <= 1);
State := machine.State;
running := State = RB_MACHINE_STATE#Execute OR State = RB_MACHINE_STATE#Stopping;

(* level: scale, smooth, hold between SP - band/2 and SP + band/2; the
   inlet follows it in Auto, and a high level closes it in every mode *)
levelIn(Raw := LevelRaw, RawMin := 0.0, RawMax := 27648.0, EngMin := 0.0, EngMax := 100.0,
        Margin := 500.0, Reset := ResetBtn);
levelPv(In := levelIn.Value, T := T#500ms);
Level := levelPv.Out;
levelCtl(Enable := TRUE, SP := LevelSP, PV := Level, Hysteresis := LevelBand);
highAlarm(In := HighLevelSw, OnDelay := T#1s, Ack := ResetBtn);
inlet(Mode := Mode, AutoOpen := levelCtl.Out, ManOpen := ManInlet, Interlock := HighLevelSw,
      FbOpen := InletOpenFb, FbClosed := InletClosedFb, Reset := ResetBtn);

(* one container, a cyclic chain: 1 wait for it, 2 dose, 3 wait until it
   is taken away, then 1 again *)
container(In := ContainerPresent, OnDelay := T#200ms, OffDelay := T#200ms);
CASE chain.StepNo OF
1: proceed := container.Out AND State = RB_MACHINE_STATE#Execute;
2: proceed := chain.StepTime >= DoseTime;
3: proceed := NOT container.Out;
END_CASE;
chain(Start := running, Proceed := proceed, NextStep := chain.StepNo MOD 3 + 1,
      Abort := NOT running);
pumpDev(Mode := Mode, AutoRun := chain.StepNo = 2, ManRun := ManPump,
        FbRunning := PumpRunningFb, Overload := PumpOverload, DryRun := NOT LowLevelSw,
        DryRunTime := T#1s, Reset := ResetBtn);
count(In := chain.StepNo = 3, Preset := BatchSize,
      Reset := State = RB_MACHINE_STATE#Starting);
Filled := count.Count;

InletValve := inlet.Open;
Pump := pumpDev.Run;
LampRunning := machine.Producing;
LampFault := fault OR State = RB_MACHINE_STATE#Aborted;
LampAlarm := highAlarm.Active OR highAlarm.Unacked;
END_FUNCTION_BLOCK
