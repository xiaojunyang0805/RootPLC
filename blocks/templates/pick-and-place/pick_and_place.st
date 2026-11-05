(* L4 template: pick-and-place cell (blocks/templates/pick-and-place/README.md).
   A two-axis gantry (X horizontal, Z vertical) with a vacuum gripper takes
   parts from a pick position and sets them down at a place position. Built
   from RootBlocks and RootMotion (--library RootBlocks --library RootMotion).
   The axes belong to the application (VAR_IN_OUT); it runs their cycle
   (RP_VirtualAxis, or a drive) after this block. No I/O inside: io_map.st
   binds it to the board. Positions in mm, Z positive downwards. *)
FUNCTION_BLOCK FB_PickPlace
VAR_INPUT
    (* operator *)
    ReqOff     : BOOL;
    ReqManual  : BOOL;
    ReqAuto    : BOOL;
    StartBtn   : BOOL;
    StopBtn    : BOOL;                 (* finishes the part in hand, then stops *)
    ResetBtn   : BOOL;                 (* homes the axes; clears an abort *)
    EStopOk    : BOOL := TRUE;
    (* plant *)
    PartAtPick : BOOL;                 (* a part waits at the pick position *)
    PlaceFree  : BOOL;                 (* the place position is empty *)
    VacuumOk   : BOOL;                 (* vacuum switch: part held *)
    (* parameters *)
    PickX      : LREAL := 100.0;
    PlaceX     : LREAL := 500.0;
    PickZ      : LREAL := 80.0;
    PlaceZ     : LREAL := 60.0;
    SpeedX     : LREAL := 1000.0;      (* mm/s *)
    SpeedZ     : LREAL := 500.0;
    Accel      : LREAL := 5000.0;      (* mm/s2 *)
END_VAR
VAR_IN_OUT
    AxisX : AXIS_REF;
    AxisZ : AXIS_REF;
END_VAR
VAR_OUTPUT
    Vacuum      : BOOL;                (* vacuum generator valve *)
    StepNo      : INT;
    State       : RB_MACHINE_STATE;
    Mode        : RB_MODE;
    Placed      : UDINT;
    LampRunning : BOOL;
    LampFault   : BOOL;
END_VAR
VAR
    modes    : RB_ModeManager;
    machine  : RB_MachineState;
    partDb   : RB_Debounce;
    placeDb  : RB_Debounce;
    vacDb    : RB_Debounce;
    chain    : RB_StepChain;
    count    : RB_Counter;
    powerX   : MC_Power;
    powerZ   : MC_Power;
    homeX    : MC_Home;
    homeZ    : MC_Home;
    moveX    : MC_MoveAbsolute;
    moveZ    : MC_MoveAbsolute;
    fault    : BOOL;
    lost     : BOOL;
    aborted  : BOOL;
    running  : BOOL;
    powered  : BOOL;
    proceed  : BOOL;
    nextStep : INT;
    limit    : TIME;
    goalX    : LREAL;
    goalZ    : LREAL;
END_VAR
VAR CONSTANT
    Debounce  : TIME := T#40ms;        (* sensors *)
    MoveLimit : TIME := T#5s;          (* a move step must end within this *)
    GripLimit : TIME := T#2s;          (* grip and release *)
    BlowOff   : TIME := T#200ms;       (* release time before lifting *)
END_VAR

(* faults: an axis in error, a step timeout, the part lost in transport *)
lost := StepNo >= 5 AND StepNo <= 7 AND NOT vacDb.Out;
fault := AxisX.State = MC_AXIS_STATE#ErrorStop OR AxisZ.State = MC_AXIS_STATE#ErrorStop
         OR chain.Error OR lost;
modes(ReqOff := ReqOff, ReqManual := ReqManual, ReqAuto := ReqAuto,
      EStopOk := EStopOk, Fault := fault);
Mode := modes.Mode;

(* resetting powers and homes both axes; stopping finishes the part *)
aborted := machine.State = RB_MACHINE_STATE#Aborted;
machine(Reset := ResetBtn AND NOT aborted, Clear := ResetBtn AND aborted,
        Start := StartBtn AND Mode = RB_MODE#Auto,
        Stop := StopBtn OR Mode <> RB_MODE#Auto,
        Abort := NOT EStopOk OR fault,
        ResetDone := AxisX.Homed AND AxisZ.Homed, StartDone := TRUE,
        StopDone := chain.StepNo <= 1);
State := machine.State;
running := State = RB_MACHINE_STATE#Execute OR State = RB_MACHINE_STATE#Stopping;

(* the axes are powered from resetting on; stopped and aborted switch them off *)
powered := State <> RB_MACHINE_STATE#Stopped AND State <> RB_MACHINE_STATE#Aborted;
powerX(Enable := powered, Axis := AxisX);
powerZ(Enable := powered, Axis := AxisZ);
homeX(Execute := State = RB_MACHINE_STATE#Resetting, Position := 0.0, Axis := AxisX);
homeZ(Execute := State = RB_MACHINE_STATE#Resetting, Position := 0.0, Axis := AxisZ);

partDb(In := PartAtPick, OnDelay := Debounce, OffDelay := Debounce);
placeDb(In := PlaceFree, OnDelay := Debounce, OffDelay := Debounce);
vacDb(In := VacuumOk, OnDelay := Debounce, OffDelay := Debounce);

(* 1 wait, 2 X to pick, 3 Z down, 4 grip, 5 Z up, 6 X to place, 7 Z down,
   8 release, 9 Z up, then 1 again *)
nextStep := 0;
limit := MoveLimit;
CASE chain.StepNo OF
1: proceed := State = RB_MACHINE_STATE#Execute AND partDb.Out AND placeDb.Out;
   limit := T#0s;
2, 6: proceed := moveX.Done;
3, 5, 7: proceed := moveZ.Done;
4: proceed := vacDb.Out;
   limit := GripLimit;
8: proceed := NOT vacDb.Out AND chain.StepTime >= BlowOff;
   limit := GripLimit;
9: proceed := moveZ.Done;
   nextStep := 1;
END_CASE;
chain(Start := running, Proceed := proceed, NextStep := nextStep, LastStep := 9,
      StepTimeout := limit, Abort := NOT running, Reset := ResetBtn);
StepNo := chain.StepNo;

(* motion: X moves only in steps 2 and 6, with Z up (steps 1, 5, 9 end at
   Z = 0); each move starts on the rising Execute of its step *)
IF StepNo = 2 THEN
    goalX := PickX;
ELSE
    goalX := PlaceX;
END_IF;
CASE StepNo OF
3: goalZ := PickZ;
7: goalZ := PlaceZ;
ELSE
   goalZ := 0.0;
END_CASE;
moveX(Execute := StepNo = 2 OR StepNo = 6, Position := goalX, Velocity := SpeedX,
      Acceleration := Accel, Deceleration := Accel, Axis := AxisX);
moveZ(Execute := StepNo = 3 OR StepNo = 5 OR StepNo = 7 OR StepNo = 9, Position := goalZ,
      Velocity := SpeedZ, Acceleration := Accel, Deceleration := Accel, Axis := AxisZ);

count(In := StepNo = 9);
Placed := count.Total;
Vacuum := StepNo >= 4 AND StepNo <= 7;
LampRunning := machine.Producing;
LampFault := State = RB_MACHINE_STATE#Aborted;
END_FUNCTION_BLOCK
