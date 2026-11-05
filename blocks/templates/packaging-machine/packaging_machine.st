(* L4 template: packaging machine, a case packer
   (blocks/templates/packaging-machine/README.md). An infeed conveyor brings
   products to a pusher, which pushes each one into a case; a full case is
   pushed out by the ejector and the next case is filled. Built only from
   RootBlocks blocks (--library RootBlocks). No I/O inside: io_map.st binds
   it to the board. *)
FUNCTION_BLOCK FB_PackagingMachine
VAR_INPUT
    (* operator *)
    ReqOff          : BOOL;
    ReqManual       : BOOL;
    ReqAuto         : BOOL;
    StartBtn        : BOOL;
    StopBtn         : BOOL;            (* finishes the product in hand, then stops *)
    HoldBtn         : BOOL;
    UnholdBtn       : BOOL;
    ResetBtn        : BOOL;            (* also acknowledges alarms *)
    ManInfeed       : BOOL;            (* manual commands *)
    ManPusher       : BOOL;
    ManEject        : BOOL;
    EStopOk         : BOOL := TRUE;    (* status from the safety relay *)
    (* plant *)
    InfeedRunningFb : BOOL;
    InfeedOverload  : BOOL;
    ProductAtPusher : BOOL;            (* photo eye in front of the pusher *)
    CaseInPlace     : BOOL;            (* a case waits at the filling place *)
    PusherExtended  : BOOL;
    PusherRetracted : BOOL;
    EjectExtended   : BOOL;
    EjectRetracted  : BOOL;
    (* parameters *)
    PerCase         : UDINT := 6;      (* products per case *)
END_VAR
VAR_OUTPUT
    InfeedMotor   : BOOL;
    PusherExtend  : BOOL;
    PusherRetract : BOOL;
    EjectExtend   : BOOL;
    EjectRetract  : BOOL;
    LampRunning   : BOOL;
    LampFault     : BOOL;
    LampAlarm     : BOOL;              (* no case to fill *)
    InCase        : UDINT;             (* products in the current case *)
    Cases         : UDINT;             (* full cases *)
    Products      : UDINT;             (* products packed *)
    StepNo        : INT;
    State         : RB_MACHINE_STATE;
    Mode          : RB_MODE;
END_VAR
VAR
    modes     : RB_ModeManager;
    machine   : RB_MachineState;
    eyeDb     : RB_Debounce;
    caseDb    : RB_Debounce;
    infeed    : RB_Motor;
    pusher    : RB_Cylinder;
    ejector   : RB_Cylinder;
    chain     : RB_StepChain;
    packed    : RB_Counter;
    noCase    : RB_Alarm;
    fault     : BOOL;
    aborted   : BOOL;
    running   : BOOL;
    producing : BOOL;
    proceed   : BOOL;
    nextStep  : INT;
END_VAR

(* devices report faults; any fault aborts the machine *)
fault := infeed.Error OR pusher.Error OR ejector.Error;
modes(ReqOff := ReqOff, ReqManual := ReqManual, ReqAuto := ReqAuto,
      EStopOk := EStopOk, Fault := fault);
Mode := modes.Mode;

(* the reset button clears an abort, otherwise it resets the machine;
   starting ends when both cylinders are home *)
aborted := machine.State = RB_MACHINE_STATE#Aborted;
machine(Reset := ResetBtn AND NOT aborted, Clear := ResetBtn AND aborted,
        Start := StartBtn AND Mode = RB_MODE#Auto,
        Stop := StopBtn OR Mode <> RB_MODE#Auto,
        Hold := HoldBtn, Unhold := UnholdBtn,
        Abort := NOT EStopOk OR fault,
        ResetDone := NOT fault, StartDone := pusher.IsRetracted AND ejector.IsRetracted,
        StopDone := chain.StepNo <= 1);
State := machine.State;
producing := State = RB_MACHINE_STATE#Execute;
running := producing OR State = RB_MACHINE_STATE#Stopping OR State = RB_MACHINE_STATE#Held;

eyeDb(In := ProductAtPusher, OnDelay := T#100ms, OffDelay := T#100ms);
caseDb(In := CaseInPlace, OnDelay := T#100ms, OffDelay := T#100ms);

(* a cyclic chain: 1 wait for a product and a case, 2 push, 3 pusher back
   (then 4 when the case is full, else 1), 4 eject the case, 5 ejector back *)
nextStep := 0;
CASE chain.StepNo OF
1: proceed := producing AND eyeDb.Out AND caseDb.Out;
2: proceed := pusher.IsExtended;
3: proceed := pusher.IsRetracted;
   IF NOT packed.Done THEN
       nextStep := 1;
   END_IF;
4: proceed := ejector.IsExtended;
5: proceed := ejector.IsRetracted;
   nextStep := 1;
ELSE
   proceed := FALSE;
END_CASE;
chain(Start := running, Proceed := proceed, NextStep := nextStep, LastStep := 5,
      Hold := State = RB_MACHINE_STATE#Held, Abort := NOT running);
StepNo := chain.StepNo;

(* a product is in the case once the pusher returns; ejecting the case
   starts the count again *)
packed(In := StepNo = 3, Preset := PerCase, Reset := StepNo = 5);
InCase := packed.Count;
Cases := packed.Batches;
Products := packed.Total;

(* devices: the infeed runs until a product waits at the pusher; the
   pusher needs a case, the ejector a retracted pusher *)
infeed(Mode := Mode, AutoRun := producing AND StepNo = 1 AND NOT eyeDb.Out,
       ManRun := ManInfeed, FbRunning := InfeedRunningFb, Overload := InfeedOverload,
       Reset := ResetBtn);
pusher(Mode := Mode, AutoExtend := StepNo = 2, ManExtend := ManPusher,
       Permissive := caseDb.Out, FbExtended := PusherExtended,
       FbRetracted := PusherRetracted, MoveTime := T#2s, Reset := ResetBtn);
ejector(Mode := Mode, AutoExtend := StepNo = 4, ManExtend := ManEject,
        Permissive := pusher.IsRetracted, FbExtended := EjectExtended,
        FbRetracted := EjectRetracted, MoveTime := T#2s, Reset := ResetBtn);
noCase(In := producing AND eyeDb.Out AND NOT caseDb.Out, OnDelay := T#5s, Ack := ResetBtn);

InfeedMotor := infeed.Run;
PusherExtend := pusher.Extend;
PusherRetract := pusher.Retract;
EjectExtend := ejector.Extend;
EjectRetract := ejector.Retract;
LampRunning := machine.Producing;
LampFault := State = RB_MACHINE_STATE#Aborted;
LampAlarm := noCase.Active OR noCase.Unacked;
END_FUNCTION_BLOCK
