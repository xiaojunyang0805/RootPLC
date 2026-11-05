(* L4 template: pump station (blocks/templates/pump-station/README.md).
   Two pumps on variable-speed drives hold a discharge pressure; the duty
   pump alternates by run hours and the standby takes over when the duty
   drive faults. Built only from RootBlocks blocks (--library RootBlocks).
   No I/O inside: io_map.st binds it to the board. *)
FUNCTION_BLOCK FB_PumpStation
VAR_INPUT
    ReqOff       : BOOL;
    ReqManual    : BOOL;
    ReqAuto      : BOOL;
    StartBtn     : BOOL;
    StopBtn      : BOOL;
    ResetBtn     : BOOL;              (* also acknowledges alarms *)
    ManRun       : ARRAY[1..2] OF BOOL;
    ManSpeed     : REAL := 50.0;      (* % in Manual *)
    EStopOk      : BOOL := TRUE;
    PressureRaw  : REAL;              (* 0 .. 27648 = 0 .. 10 bar *)
    SuctionOk    : BOOL;              (* TRUE: enough water on the suction side *)
    DriveReady   : ARRAY[1..2] OF BOOL;
    DriveRunning : ARRAY[1..2] OF BOOL;
    DriveFault   : ARRAY[1..2] OF BOOL;
    ActualSpeed  : ARRAY[1..2] OF REAL;
    PressureSP   : REAL := 4.0;       (* bar *)
    HighPressure : REAL := 8.0;       (* bar: pumps stop above this *)
    MinSpeed     : REAL := 30.0;      (* % *)
END_VAR
VAR_OUTPUT
    Run         : ARRAY[1..2] OF BOOL;
    Speed       : ARRAY[1..2] OF REAL;
    ResetDrive  : ARRAY[1..2] OF BOOL;
    Duty        : INT := 1;           (* the pump that runs in Auto *)
    Pressure    : REAL;               (* bar *)
    Hours       : ARRAY[1..2] OF LREAL;
    LampRunning : BOOL;
    LampFault   : BOOL;
    LampAlarm   : BOOL;
    State       : RB_MACHINE_STATE;
    Mode        : RB_MODE;
END_VAR
VAR
    modes     : RB_ModeManager;
    machine   : RB_MachineState;
    pressIn   : RB_Scale;
    pressPv   : RB_FilterPT1;
    pid       : RB_PID;
    drive     : ARRAY[1..2] OF RB_Drive;
    meter     : ARRAY[1..2] OF RB_RunHours;
    highAlarm : RB_Alarm;
    suction   : RB_Alarm;
    fault     : BOOL;
    aborted   : BOOL;
    running   : BOOL;
    blocked   : BOOL;
    i         : INT;
END_VAR

(* the station fails only when no pump is left or the pressure is unknown *)
fault := (drive[1].Error AND drive[2].Error) OR pressIn.Error;
modes(ReqOff := ReqOff, ReqManual := ReqManual, ReqAuto := ReqAuto,
      EStopOk := EStopOk, Fault := fault);
Mode := modes.Mode;
aborted := machine.State = RB_MACHINE_STATE#Aborted;
machine(Reset := ResetBtn AND NOT aborted, Clear := ResetBtn AND aborted,
        Start := StartBtn AND Mode = RB_MODE#Auto,
        Stop := StopBtn OR Mode <> RB_MODE#Auto,
        Abort := NOT EStopOk OR fault,
        ResetDone := NOT fault, StartDone := TRUE, StopDone := TRUE);
State := machine.State;
running := State = RB_MACHINE_STATE#Execute;

(* pressure *)
pressIn(Raw := PressureRaw, RawMin := 0.0, RawMax := 27648.0, EngMin := 0.0, EngMax := 10.0,
        Margin := 500.0, Reset := ResetBtn);
pressPv(In := pressIn.Value, T := T#200ms);
Pressure := pressPv.Out;
highAlarm(In := Pressure > HighPressure, Ack := ResetBtn);
suction(In := NOT SuctionOk, OnDelay := T#500ms, Ack := ResetBtn);
blocked := highAlarm.Active OR suction.Active;

(* duty: chosen by run hours whenever no pump runs; the standby takes over
   when the duty drive faults *)
IF NOT Run[1] AND NOT Run[2] THEN
    IF Hours[2] < Hours[1] THEN
        Duty := 2;
    ELSE
        Duty := 1;
    END_IF;
END_IF;
IF drive[Duty].Error THEN
    Duty := 3 - Duty;
END_IF;

IF running AND NOT blocked THEN
    pid(Mode := RB_MODE#Auto, SP := PressureSP, PV := Pressure, Kp := 10.0, Ti := T#2s,
        OutMin := MinSpeed, OutMax := 100.0);
ELSE
    pid(Mode := RB_MODE#Off, SP := PressureSP, PV := Pressure, Kp := 10.0, Ti := T#2s,
        OutMin := MinSpeed, OutMax := 100.0);
END_IF;
FOR i := 1 TO 2 DO
    drive[i](Mode := Mode,
             AutoRun := running AND NOT blocked AND i = Duty, AutoSpeed := pid.Out,
             ManRun := ManRun[i], ManSpeed := ManSpeed,
             Interlock := blocked,
             DriveReady := DriveReady[i], DriveRunning := DriveRunning[i],
             DriveFault := DriveFault[i], ActualSpeed := ActualSpeed[i],
             SpeedMin := 0.0, SpeedMax := 100.0, Reset := ResetBtn);
    meter[i](Running := drive[i].Running);
    Run[i] := drive[i].Run;
    Speed[i] := drive[i].SpeedSetpoint;
    ResetDrive[i] := drive[i].ResetDrive;
    Hours[i] := meter[i].Hours;
END_FOR;

LampRunning := machine.Producing;
LampFault := State = RB_MACHINE_STATE#Aborted;
LampAlarm := highAlarm.Active OR highAlarm.Unacked OR suction.Active OR suction.Unacked
             OR drive[1].Error OR drive[2].Error;
END_FUNCTION_BLOCK
