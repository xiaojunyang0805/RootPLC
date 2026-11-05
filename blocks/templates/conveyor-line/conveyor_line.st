(* L4 template: conveyor line (blocks/templates/conveyor-line/README.md).
   Three zero-pressure accumulation zones in a row, each with a photo eye
   and a motor. Built only from RootBlocks blocks (--library RootBlocks).
   No I/O inside: io_map.st binds it to the board. To lengthen the line,
   change the array bounds 1..3 everywhere in this file. *)
FUNCTION_BLOCK FB_ConveyorLine
VAR_INPUT
    ReqOff     : BOOL;
    ReqManual  : BOOL;
    ReqAuto    : BOOL;
    StartBtn   : BOOL;
    StopBtn    : BOOL;
    ResetBtn   : BOOL;
    ManJog     : BOOL;                   (* manual: run every zone *)
    EStopOk    : BOOL := TRUE;
    Eye        : ARRAY[1..3] OF BOOL;     (* photo eye at each zone end *)
    MotorFb    : ARRAY[1..3] OF BOOL;     (* contactor feedback *)
    Overload   : ARRAY[1..3] OF BOOL;
    OutfeedFree : BOOL;                  (* the next machine can take a part *)
    InfeedFeeding : BOOL;                (* the previous machine hands a part to zone 1 *)
    SleepTime  : TIME := T#10s;
    JamTime    : TIME := T#5s;
END_VAR
VAR_OUTPUT
    Motor       : ARRAY[1..3] OF BOOL;
    LampRunning : BOOL;
    LampFault   : BOOL;
    Delivered   : UDINT;                 (* parts handed to the next machine *)
    State       : RB_MACHINE_STATE;
    Mode        : RB_MODE;
END_VAR
VAR
    modes   : RB_ModeManager;
    machine : RB_MachineState;
    eyeDb   : ARRAY[1..3] OF RB_Debounce;
    zone    : ARRAY[1..3] OF RB_ConveyorZone;
    motorDev : ARRAY[1..3] OF RB_Motor;
    i       : INT;
    fault   : BOOL;
    aborted : BOOL;
    free    : BOOL;
    feeding : BOOL;
END_VAR

fault := FALSE;
FOR i := 1 TO 3 DO
    fault := fault OR zone[i].Error OR motorDev[i].Error;
END_FOR;
modes(ReqOff := ReqOff, ReqManual := ReqManual, ReqAuto := ReqAuto,
      EStopOk := EStopOk, Fault := fault);
Mode := modes.Mode;
(* the reset button clears an abort, otherwise it resets the machine *)
aborted := machine.State = RB_MACHINE_STATE#Aborted;
machine(Reset := ResetBtn AND NOT aborted, Clear := ResetBtn AND aborted,
        Start := StartBtn AND Mode = RB_MODE#Auto,
        Stop := StopBtn OR Mode <> RB_MODE#Auto,
        Abort := NOT EStopOk OR fault,
        ResetDone := NOT fault, StartDone := TRUE, StopDone := TRUE);
State := machine.State;

(* zones from the outfeed backwards, so each sees whether the next is free;
   a zone is fed by the previous one *)
free := OutfeedFree;
FOR i := 3 TO 1 BY -1 DO
    eyeDb[i](In := Eye[i], OnDelay := T#50ms, OffDelay := T#50ms);
    IF i > 1 THEN
        feeding := zone[i - 1].Feeding;
    ELSE
        feeding := InfeedFeeding;
    END_IF;
    zone[i](Enable := State = RB_MACHINE_STATE#Execute, PartAtEnd := eyeDb[i].Out,
            DownstreamFree := free, UpstreamFeeding := feeding,
            SleepTime := SleepTime, JamTime := JamTime, Reset := ResetBtn);
    free := zone[i].Free;
    motorDev[i](Mode := Mode, AutoRun := zone[i].Run, ManRun := ManJog,
             FbRunning := MotorFb[i], Overload := Overload[i], Reset := ResetBtn);
    Motor[i] := motorDev[i].Run;
END_FOR;
Delivered := zone[3].Count;
LampRunning := machine.Producing;
LampFault := fault OR State = RB_MACHINE_STATE#Aborted;
END_FUNCTION_BLOCK
