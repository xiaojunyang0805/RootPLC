(* The batch mixer on a controller: located I/O bound to the template
   (spec/14-runtime.md). The recipe table lives here; an HMI edits it
   (runtime v0 retains elementary RETAIN variables only, so keep a copy of
   the table in the HMI or a file until arrays are retained).
   Run: rootplc runtime blocks/templates/batch-mixer --library RootBlocks
        --program PLC_PRG --modbus 5502 *)
PROGRAM PLC_PRG
VAR
    btnAuto     AT %IX0.0 : BOOL;
    btnManual   AT %IX0.1 : BOOL;
    btnOff      AT %IX0.2 : BOOL;
    btnStart    AT %IX0.3 : BOOL;
    btnHold     AT %IX0.4 : BOOL;
    btnRestart  AT %IX0.5 : BOOL;
    btnStop     AT %IX0.6 : BOOL;
    btnAbort    AT %IX0.7 : BOOL;
    btnReset    AT %IX1.0 : BOOL;
    estopOk     AT %IX1.1 : BOOL;
    agitatorFb  AT %IX1.2 : BOOL;
    agitatorOl  AT %IX1.3 : BOOL;
    weightRaw   AT %IW2 : INT;
    tempRaw     AT %IW4 : INT;
    recipeNo    AT %MW0 : INT;        (* chosen on the HMI *)
    valveA      AT %QX0.0 : BOOL;
    valveB      AT %QX0.1 : BOOL;
    drainValve  AT %QX0.2 : BOOL;
    agitator    AT %QX0.3 : BOOL;
    lampRunning AT %QX0.4 : BOOL;
    lampFault   AT %QX0.5 : BOOL;
    lampAlarm   AT %QX0.6 : BOOL;
    heaterOut   AT %QW2 : INT;        (* 0 .. 27648 = 0 .. 100 % *)
    stepOut     AT %QW4 : INT;
    mixer       : FB_BatchMixer;
    recipes     : ARRAY[1..16, 1..8] OF REAL;
END_VAR
mixer(ReqAuto := btnAuto, ReqManual := btnManual, ReqOff := btnOff,
      StartBtn := btnStart, HoldBtn := btnHold, RestartBtn := btnRestart,
      StopBtn := btnStop, AbortBtn := btnAbort, ResetBtn := btnReset,
      RecipeNo := recipeNo, EStopOk := estopOk,
      WeightRaw := INT_TO_REAL(weightRaw), TempRaw := INT_TO_REAL(tempRaw),
      AgitatorFb := agitatorFb, AgitatorOverload := agitatorOl, Recipes := recipes);
valveA := mixer.ValveA;
valveB := mixer.ValveB;
drainValve := mixer.DrainValve;
agitator := mixer.Agitator;
heaterOut := REAL_TO_INT(mixer.HeaterPower * 276.48);
stepOut := mixer.StepNo;
lampRunning := mixer.LampRunning;
lampFault := mixer.LampFault;
lampAlarm := mixer.LampAlarm;
END_PROGRAM
