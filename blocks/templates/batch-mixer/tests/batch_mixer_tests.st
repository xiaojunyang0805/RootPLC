(* Tests of the batch-mixer template against a simulated mixing tank. One
   bench call = one 100 ms PLC cycle: each open dosing valve adds 1 kg, the
   drain takes 4 kg; the heater warms the contents (0.2 degC per cycle at
   full power) and the tank loses heat to its 20 degC surroundings. *)
FUNCTION_BLOCK FB_TankSim
VAR_INPUT
    ValveA, ValveB, Drain, Agitator : BOOL;
    HeaterPower : REAL;
    StuckHot    : BOOL;               (* the temperature reads 120 degC *)
    ScaleBroken : BOOL;               (* the load cell reads far over range *)
END_VAR
VAR_OUTPUT
    WeightRaw  : REAL;
    TempRaw    : REAL;
    AgitatorFb : BOOL;
END_VAR
VAR
    kg   : REAL;
    degC : REAL := 20.0;
END_VAR
IF ValveA THEN kg := kg + 1.0; END_IF;
IF ValveB THEN kg := kg + 1.0; END_IF;
IF Drain THEN kg := MAX(0.0, kg - 4.0); END_IF;
degC := degC + HeaterPower * 0.002 - (degC - 20.0) * 0.001;
AgitatorFb := Agitator;
IF ScaleBroken THEN
    WeightRaw := 32000.0;
ELSE
    WeightRaw := kg * 27.648;
END_IF;
IF StuckHot THEN
    TempRaw := 120.0 * 184.32;
ELSE
    TempRaw := degC * 184.32;
END_IF;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_MixerBench
VAR_INPUT
    ReqAuto, ReqManual, ReqOff : BOOL;
    StartBtn, HoldBtn, RestartBtn, StopBtn, AbortBtn, ResetBtn : BOOL;
    RecipeNo    : INT := 1;
    ManAgitator : BOOL;
    EStopOk     : BOOL := TRUE;
    StuckHot    : BOOL;
    ScaleBroken : BOOL;
END_VAR
VAR
    sim     : FB_TankSim;
    mixer   : FB_BatchMixer;
    recipes : ARRAY[1..16, 1..8] OF REAL;
    loaded  : BOOL;
END_VAR
IF NOT loaded THEN
    (* recipe 1: 20 kg A, 10 kg B, 40 degC, 3 s mixing *)
    recipes[1, 1] := 20.0;
    recipes[1, 2] := 10.0;
    recipes[1, 3] := 40.0;
    recipes[1, 4] := 3.0;
    loaded := TRUE;
END_IF;
sim(ValveA := mixer.ValveA, ValveB := mixer.ValveB, Drain := mixer.DrainValve,
    Agitator := mixer.Agitator, HeaterPower := mixer.HeaterPower, StuckHot := StuckHot,
    ScaleBroken := ScaleBroken);
mixer(ReqAuto := ReqAuto, ReqManual := ReqManual, ReqOff := ReqOff,
      StartBtn := StartBtn, HoldBtn := HoldBtn, RestartBtn := RestartBtn,
      StopBtn := StopBtn, AbortBtn := AbortBtn, ResetBtn := ResetBtn,
      RecipeNo := RecipeNo, ManAgitator := ManAgitator, EStopOk := EStopOk,
      WeightRaw := sim.WeightRaw, TempRaw := sim.TempRaw,
      AgitatorFb := sim.AgitatorFb, AgitatorOverload := FALSE, Recipes := recipes);
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_MixerStarted
VAR_IN_OUT
    b : FB_MixerBench;
END_VAR
b(ReqAuto := TRUE);
b(ReqAuto := FALSE, StartBtn := TRUE);
b(StartBtn := FALSE);
END_FUNCTION_BLOCK

TEST mixer_makes_a_batch
VAR b : FB_MixerBench; s : FB_MixerStarted; i : INT; heated : BOOL; mixedAt, heatAt : REAL;
    mixCycles : INT; agitating : BOOL := TRUE; END_VAR
s(b := b);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Running);
ASSERT_EQ(1, b.mixer.StepNo);
ASSERT_TRUE(b.mixer.ValveA);
ASSERT_FALSE(b.mixer.ValveB);
ASSERT_FALSE(b.mixer.Agitator);
ASSERT_TRUE(b.mixer.HeaterPower < 0.001);
ASSERT_TRUE(b.mixer.LampRunning);
FOR i := 1 TO 25 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_EQ(2, b.mixer.StepNo);
ASSERT_TRUE(b.mixer.ValveB);
ASSERT_FALSE(b.mixer.ValveA);
FOR i := 1 TO 15 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_EQ(3, b.mixer.StepNo);
ASSERT_TRUE(ABS(b.mixer.Weight - 30.0) < 1.5);
ASSERT_TRUE(b.mixer.Agitator);
ASSERT_TRUE(b.mixer.HeaterPower > 90.0);
FOR i := 1 TO 400 DO
    ADVANCE(T#100ms);
    b();
    IF b.mixer.StepNo = 4 AND NOT heated THEN
        heated := TRUE;
        mixedAt := b.mixer.Temp;
        heatAt := b.mixer.HeaterPower;
    END_IF;
    IF b.mixer.StepNo = 4 THEN
        mixCycles := mixCycles + 1;
        agitating := agitating AND b.mixer.Agitator;
    END_IF;
    IF b.mixer.Phase = RB_PHASE_STATE#Complete THEN EXIT; END_IF;
END_FOR;
ASSERT_TRUE(heated);
ASSERT_TRUE(mixedAt >= 39.0);
ASSERT_TRUE(mixedAt < 40.0);
(* temperature control takes over from full power without a bump *)
ASSERT_TRUE(heatAt > 20.0);
(* mixing lasts the recipe's 3 s with the agitator running *)
ASSERT_TRUE(mixCycles >= 29 AND mixCycles <= 32);
ASSERT_TRUE(agitating);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Complete);
ASSERT_EQ(UDINT#1, b.mixer.Batches);
ASSERT_TRUE(b.mixer.Weight < 1.0);
ASSERT_FALSE(b.mixer.DrainValve OR b.mixer.Agitator OR b.mixer.ValveA);
ASSERT_TRUE(b.mixer.HeaterPower < 0.001);
(* reset for the next batch *)
b(ResetBtn := TRUE);
b(ResetBtn := FALSE);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Idle);
END_TEST

TEST mixer_hold_and_restart
VAR b : FB_MixerBench; s : FB_MixerStarted; i : INT; w : REAL; END_VAR
s(b := b);
FOR i := 1 TO 10 DO ADVANCE(T#100ms); b(); END_FOR;
b(HoldBtn := TRUE);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Held);
FOR i := 1 TO 3 DO ADVANCE(T#100ms); b(HoldBtn := FALSE); END_FOR;
ASSERT_FALSE(b.mixer.ValveA);
w := b.mixer.Weight;
FOR i := 1 TO 20 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(ABS(b.mixer.Weight - w) < 0.01);
ASSERT_EQ(1, b.mixer.StepNo);
b(RestartBtn := TRUE);
b(RestartBtn := FALSE);
ASSERT_TRUE(b.mixer.ValveA);
(* the 10 kg of A still missing take 10 cycles *)
FOR i := 1 TO 13 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_EQ(2, b.mixer.StepNo);
END_TEST

TEST mixer_over_temperature_aborts
VAR b : FB_MixerBench; s : FB_MixerStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 5 DO ADVANCE(T#100ms); b(); END_FOR;
FOR i := 1 TO 60 DO ADVANCE(T#100ms); b(StuckHot := TRUE); END_FOR;
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Aborted);
ASSERT_TRUE(b.mixer.LampFault);
ASSERT_TRUE(b.mixer.LampAlarm);
ASSERT_FALSE(b.mixer.ValveA OR b.mixer.ValveB OR b.mixer.Agitator);
ASSERT_TRUE(b.mixer.Mode = RB_MODE#Off);
(* temperature normal again: the alarm waits for acknowledgement *)
FOR i := 1 TO 60 DO ADVANCE(T#100ms); b(StuckHot := FALSE); END_FOR;
ASSERT_TRUE(b.mixer.LampAlarm);
b(ResetBtn := TRUE);
ASSERT_FALSE(b.mixer.LampAlarm);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Idle);
END_TEST

TEST mixer_stop_and_emergency_stop
VAR b : FB_MixerBench; s : FB_MixerStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 5 DO ADVANCE(T#100ms); b(); END_FOR;
b(StopBtn := TRUE);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Stopped);
ASSERT_FALSE(b.mixer.ValveA);
ASSERT_EQ(0, b.mixer.StepNo);
b(StopBtn := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE, StartBtn := TRUE);
b(StartBtn := FALSE);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Running);
b(EStopOk := FALSE);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Aborted);
ASSERT_FALSE(b.mixer.ValveA);
b(EStopOk := TRUE, AbortBtn := TRUE);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Aborted);
END_TEST

TEST mixer_invalid_recipe_does_not_start
VAR b : FB_MixerBench; END_VAR
b(ReqAuto := TRUE);
b(ReqAuto := FALSE, StartBtn := TRUE, RecipeNo := 20);
b(StartBtn := FALSE);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Idle);
ASSERT_FALSE(b.mixer.ValveA);
(* and Start is ignored outside Auto *)
b(ReqOff := TRUE, RecipeNo := 1);
b(ReqOff := FALSE, StartBtn := TRUE);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Idle);
END_TEST

TEST mixer_manual_agitator
VAR b : FB_MixerBench; END_VAR
b(ReqManual := TRUE);
b(ReqManual := FALSE, ManAgitator := TRUE);
ASSERT_TRUE(b.mixer.Agitator);
ASSERT_TRUE(b.mixer.Mode = RB_MODE#Manual);
b(ManAgitator := FALSE);
ASSERT_FALSE(b.mixer.Agitator);
END_TEST

TEST mixer_broken_scale_aborts
VAR b : FB_MixerBench; s : FB_MixerStarted; END_VAR
s(b := b);
ADVANCE(T#100ms);
b(ScaleBroken := TRUE);
ADVANCE(T#100ms);
b(ScaleBroken := TRUE);
ASSERT_TRUE(b.mixer.Phase = RB_PHASE_STATE#Aborted);
ASSERT_FALSE(b.mixer.ValveA);
ASSERT_FALSE(b.mixer.LampRunning);
END_TEST
