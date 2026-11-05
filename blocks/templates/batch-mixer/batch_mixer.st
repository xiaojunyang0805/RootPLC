(* L4 template: batch mixer (blocks/templates/batch-mixer/README.md).
   A heated mixing tank makes batches from a recipe: dose ingredient A and
   B by weight, heat with the agitator running, mix at temperature, drain.
   Built only from RootBlocks blocks (--library RootBlocks). No I/O inside:
   io_map.st binds it to the board. Recipe row: [1] kg of A, [2] kg of B,
   [3] temperature in degC, [4] mix time in s. *)
FUNCTION_BLOCK FB_BatchMixer
VAR_INPUT
    ReqOff     : BOOL;
    ReqManual  : BOOL;
    ReqAuto    : BOOL;
    StartBtn   : BOOL;              (* loads the recipe and starts a batch *)
    HoldBtn    : BOOL;
    RestartBtn : BOOL;
    StopBtn    : BOOL;
    AbortBtn   : BOOL;
    ResetBtn   : BOOL;              (* resets the phase and devices, acknowledges alarms *)
    RecipeNo   : INT := 1;
    ManAgitator : BOOL;
    EStopOk    : BOOL := TRUE;
    WeightRaw  : REAL;              (* load cells, 0 .. 27648 = 0 .. 1000 kg *)
    TempRaw    : REAL;              (* 0 .. 27648 = 0 .. 150 degC *)
    AgitatorFb : BOOL;
    AgitatorOverload : BOOL;
    MaxTemp    : REAL := 90.0;      (* degC: above this the batch aborts *)
END_VAR
VAR_IN_OUT
    Recipes : ARRAY[1..16, 1..8] OF REAL;
END_VAR
VAR_OUTPUT
    ValveA      : BOOL;
    ValveB      : BOOL;
    DrainValve  : BOOL;
    Agitator    : BOOL;
    HeaterPower : REAL;             (* % *)
    StepNo      : INT;
    Phase       : RB_PHASE_STATE;
    Mode        : RB_MODE;
    Weight      : REAL;             (* kg *)
    Temp        : REAL;             (* degC *)
    Batches     : UDINT;
    LampRunning : BOOL;
    LampFault   : BOOL;
    LampAlarm   : BOOL;
END_VAR
VAR
    modes    : RB_ModeManager;
    fbPhase  : RB_Phase;
    recipe   : RB_RecipeTable;
    chain    : RB_StepChain;
    weightIn : RB_Scale;
    tempIn   : RB_Scale;
    tempPv   : RB_FilterPT1;
    heater   : RB_PID;
    fbValveA : RB_ValveOnOff;
    fbValveB : RB_ValveOnOff;
    drain    : RB_ValveOnOff;
    fbAgitator : RB_Motor;
    overTemp : RB_Alarm;
    fbBatches : RB_Counter;
    fault    : BOOL;
    running  : BOOL;
    proceed  : BOOL;
    stepNow  : INT;
    noFb     : BOOL;
    heatMode : RB_MODE;
END_VAR

(* measurements *)
weightIn(Raw := WeightRaw, RawMin := 0.0, RawMax := 27648.0, EngMin := 0.0, EngMax := 1000.0,
         Margin := 500.0, Reset := ResetBtn);
Weight := weightIn.Value;
tempIn(Raw := TempRaw, RawMin := 0.0, RawMax := 27648.0, EngMin := 0.0, EngMax := 150.0,
       Margin := 500.0, Reset := ResetBtn);
tempPv(In := tempIn.Value, T := T#1s);
Temp := tempPv.Out;
overTemp(In := Temp > MaxTemp, Ack := ResetBtn);

fault := fbAgitator.Error OR weightIn.Error OR tempIn.Error OR overTemp.Active;
modes(ReqOff := ReqOff, ReqManual := ReqManual, ReqAuto := ReqAuto,
      EStopOk := EStopOk, Fault := fault);
Mode := modes.Mode;

(* the recipe is loaded with the start command *)
recipe(Number := RecipeNo, Load := StartBtn AND fbPhase.State = RB_PHASE_STATE#Idle,
       Table := Recipes);
fbPhase(Start := StartBtn AND Mode = RB_MODE#Auto AND NOT recipe.Error,
      Hold := HoldBtn, Restart := RestartBtn,
      Stop := StopBtn OR Mode = RB_MODE#Off,
      Abort := AbortBtn OR fault OR NOT EStopOk,
      Reset := ResetBtn, Finished := chain.Done);
Phase := fbPhase.State;
running := Phase = RB_PHASE_STATE#Running OR Phase = RB_PHASE_STATE#Held;

(* 1 dose A, 2 dose B, 3 heat, 4 mix at temperature, 5 drain *)
stepNow := chain.StepNo;
CASE stepNow OF
1: proceed := Weight >= recipe.Params[1];
2: proceed := Weight >= recipe.Params[1] + recipe.Params[2];
3: proceed := Temp >= recipe.Params[3] - 1.0;
4: proceed := chain.StepTime >= LREAL_TO_TIME(REAL_TO_LREAL(recipe.Params[4]) * 1000.0);
5: proceed := Weight < 1.0;
ELSE
    proceed := FALSE;
END_CASE;
chain(Start := running, Proceed := proceed, LastStep := 5,
      Hold := Phase = RB_PHASE_STATE#Held, Abort := NOT running);
StepNo := chain.StepNo;
fbBatches(In := chain.Done);
Batches := fbBatches.Total;

(* devices: dosing and draining valves without limit switches *)
noFb := FALSE;
fbValveA(Mode := Mode, AutoOpen := Phase = RB_PHASE_STATE#Running AND StepNo = 1,
       Feedback := noFb, Reset := ResetBtn);
fbValveB(Mode := Mode, AutoOpen := Phase = RB_PHASE_STATE#Running AND StepNo = 2,
       Feedback := noFb, Reset := ResetBtn);
drain(Mode := Mode, AutoOpen := Phase = RB_PHASE_STATE#Running AND StepNo = 5,
      Feedback := noFb, Reset := ResetBtn);
fbAgitator(Mode := Mode, AutoRun := Phase = RB_PHASE_STATE#Running AND (StepNo = 3 OR StepNo = 4),
         ManRun := ManAgitator, FbRunning := AgitatorFb, Overload := AgitatorOverload,
         Reset := ResetBtn);
(* heat up at full power (step 3), then hold the temperature (step 4); the
   switch from Manual to Auto is bumpless, so control starts at 100 % *)
IF Phase = RB_PHASE_STATE#Running AND StepNo = 3 THEN
    heatMode := RB_MODE#Manual;
ELSIF Phase = RB_PHASE_STATE#Running AND StepNo = 4 THEN
    heatMode := RB_MODE#Auto;
ELSE
    heatMode := RB_MODE#Off;
END_IF;
heater(Mode := heatMode, ManValue := 100.0, SP := recipe.Params[3], PV := Temp,
       Kp := 8.0, Ti := T#20s, OutMin := 0.0, OutMax := 100.0);

ValveA := fbValveA.Open;
ValveB := fbValveB.Open;
DrainValve := drain.Open;
Agitator := fbAgitator.Run;
HeaterPower := heater.Out;
LampRunning := Phase = RB_PHASE_STATE#Running;
LampFault := Phase = RB_PHASE_STATE#Aborted;
LampAlarm := overTemp.Active OR overTemp.Unacked OR fbAgitator.Error;
END_FUNCTION_BLOCK
