(* Tests of the filling-station template against a simulated tank.
   One bench call = one 100 ms PLC cycle: the plant reacts to the outputs of
   the previous cycle. *)
FUNCTION_BLOCK FB_TankSim
VAR_INPUT
    InletValve : BOOL;
    Pump       : BOOL;
    Init       : BOOL;                 (* TRUE: level := InitLevel *)
    InitLevel  : REAL := 30.0;         (* % *)
END_VAR
VAR_OUTPUT
    LevelRaw      : REAL;
    HighLevelSw   : BOOL;
    LowLevelSw    : BOOL;
    InletOpenFb   : BOOL;
    InletClosedFb : BOOL := TRUE;
    PumpRunningFb : BOOL;
END_VAR
VAR
    level   : REAL;
    started : BOOL;
END_VAR
IF Init OR NOT started THEN
    level := InitLevel;
    started := TRUE;
END_IF;
(* 5 %/s in, 10 %/s out, per 100 ms *)
IF InletOpenFb THEN
    level := level + 0.5;
END_IF;
IF PumpRunningFb AND level > 0.0 THEN
    level := level - 1.0;
END_IF;
level := LIMIT(0.0, level, 100.0);
InletOpenFb := InletValve;
InletClosedFb := NOT InletValve;
PumpRunningFb := Pump;
LevelRaw := level * 276.48;
HighLevelSw := level > 90.0;
LowLevelSw := level > 5.0;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Bench
VAR_INPUT
    ReqAuto, ReqManual, ReqOff : BOOL;
    StartBtn, StopBtn, ResetBtn : BOOL;
    ManInlet, ManPump : BOOL;
    EStopOk   : BOOL := TRUE;
    Container : BOOL;
    Init      : BOOL;
    InitLevel : REAL := 30.0;
    BatchSize : UDINT := 10;
    LevelSP   : REAL := 60.0;
END_VAR
VAR
    sim : FB_TankSim;
    st  : FB_FillingStation;
END_VAR
sim(InletValve := st.InletValve, Pump := st.Pump, Init := Init, InitLevel := InitLevel);
st(ReqAuto := ReqAuto, ReqManual := ReqManual, ReqOff := ReqOff,
   StartBtn := StartBtn, StopBtn := StopBtn, ResetBtn := ResetBtn,
   ManInlet := ManInlet, ManPump := ManPump, EStopOk := EStopOk,
   LevelRaw := sim.LevelRaw, HighLevelSw := sim.HighLevelSw, LowLevelSw := sim.LowLevelSw,
   InletOpenFb := sim.InletOpenFb, InletClosedFb := sim.InletClosedFb,
   PumpRunningFb := sim.PumpRunningFb, PumpOverload := FALSE,
   ContainerPresent := Container, BatchSize := BatchSize, LevelSP := LevelSP);
END_FUNCTION_BLOCK

(* power up, Auto, reset, start: the station is producing *)
FUNCTION_BLOCK FB_Started
VAR_INPUT
    InitLevel : REAL := 30.0;
    BatchSize : UDINT := 10;
END_VAR
VAR_OUTPUT
    Ok : BOOL;
END_VAR
VAR_IN_OUT
    b : FB_Bench;
END_VAR
b(Init := TRUE, InitLevel := InitLevel, BatchSize := BatchSize);
b(Init := FALSE, ReqAuto := TRUE);
b(ReqAuto := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
b(StartBtn := TRUE);
b(StartBtn := FALSE);
Ok := b.st.State = RB_MACHINE_STATE#Execute AND b.st.Mode = RB_MODE#Auto;
END_FUNCTION_BLOCK

TEST station_starts_and_holds_the_tank_level
VAR b : FB_Bench; s : FB_Started; i : INT; END_VAR
b();
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopped);
ASSERT_TRUE(b.st.Mode = RB_MODE#Off);
ASSERT_FALSE(b.st.InletValve);
s(b := b);
ASSERT_TRUE(s.Ok);
ASSERT_TRUE(b.st.LampRunning);
FOR i := 1 TO 150 DO
    ADVANCE(T#100ms);
    b();
END_FOR;
(* filled from 30 % up to SP + band/2 = 70 %, then the inlet closed *)
ASSERT_TRUE(b.st.Level > 65.0 AND b.st.Level < 75.0);
ASSERT_FALSE(b.st.InletValve);
ASSERT_FALSE(b.st.LampFault);
ASSERT_FALSE(b.st.LampAlarm);
END_TEST

TEST station_fills_one_container
VAR b : FB_Bench; s : FB_Started; i : INT; pumped : INT; END_VAR
s(b := b, InitLevel := 70.0);
b(Container := TRUE);
FOR i := 1 TO 50 DO
    ADVANCE(T#100ms);
    b(Container := TRUE);
    IF b.st.Pump THEN pumped := pumped + 1; END_IF;
END_FOR;
(* the dose: 3 s of pumping, give or take a cycle *)
ASSERT_TRUE(pumped >= 29 AND pumped <= 32);
ASSERT_FALSE(b.st.Pump);
(* counted when the dose is complete *)
ASSERT_EQ(UDINT#1, b.st.Filled);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    b(Container := FALSE);
END_FOR;
ASSERT_EQ(UDINT#1, b.st.Filled);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Execute);
END_TEST

TEST station_stops_after_the_batch
VAR b : FB_Bench; s : FB_Started; i : INT; k : INT; END_VAR
s(b := b, InitLevel := 70.0, BatchSize := 2);
FOR k := 1 TO 2 DO
    FOR i := 1 TO 45 DO
        ADVANCE(T#100ms);
        b(Container := TRUE);
    END_FOR;
    FOR i := 1 TO 5 DO
        ADVANCE(T#100ms);
        b(Container := FALSE);
    END_FOR;
END_FOR;
ASSERT_EQ(UDINT#2, b.st.Filled);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopped);
ASSERT_FALSE(b.st.LampRunning);
END_TEST

TEST station_stop_finishes_the_current_container
VAR b : FB_Bench; s : FB_Started; i : INT; END_VAR
s(b := b, InitLevel := 70.0);
FOR i := 1 TO 15 DO
    ADVANCE(T#100ms);
    b(Container := TRUE);
END_FOR;
ASSERT_TRUE(b.st.Pump);
b(Container := TRUE, StopBtn := TRUE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopping);
FOR i := 1 TO 10 DO
    ADVANCE(T#100ms);
    b(Container := TRUE, StopBtn := FALSE);
END_FOR;
ASSERT_TRUE(b.st.Pump);
FOR i := 1 TO 30 DO
    ADVANCE(T#100ms);
    b(Container := TRUE);
END_FOR;
ASSERT_FALSE(b.st.Pump);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopping);
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    b(Container := FALSE);
END_FOR;
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopped);
ASSERT_EQ(UDINT#1, b.st.Filled);
END_TEST

TEST station_emergency_stop_aborts
VAR b : FB_Bench; s : FB_Started; i : INT; END_VAR
s(b := b, InitLevel := 30.0);
ADVANCE(T#100ms);
b();
ASSERT_TRUE(b.st.InletValve);
b(EStopOk := FALSE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Aborted);
ASSERT_TRUE(b.st.Mode = RB_MODE#Off);
ASSERT_FALSE(b.st.InletValve);
ASSERT_FALSE(b.st.Pump);
ASSERT_TRUE(b.st.LampFault);
(* the start button does nothing until cleared and reset *)
b(EStopOk := TRUE, StartBtn := TRUE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Aborted);
b(StartBtn := FALSE, ResetBtn := TRUE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopped);
b(ResetBtn := FALSE);
b(ResetBtn := TRUE);
b(ResetBtn := FALSE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Idle);
ASSERT_FALSE(b.st.LampFault);
END_TEST

TEST station_pump_running_dry_aborts
VAR b : FB_Bench; s : FB_Started; i : INT; END_VAR
s(b := b, InitLevel := 4.0);
FOR i := 1 TO 3 DO
    ADVANCE(T#100ms);
    b(Container := TRUE, Init := FALSE);
END_FOR;
(* the inlet is still filling, but the pump starts below the low switch *)
FOR i := 1 TO 15 DO
    ADVANCE(T#100ms);
    b(Container := TRUE, Init := TRUE, InitLevel := 2.0);
END_FOR;
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Aborted);
ASSERT_TRUE(b.st.LampFault);
ASSERT_FALSE(b.st.Pump);
ASSERT_TRUE(b.st.Mode = RB_MODE#Off);
END_TEST

TEST station_high_level_closes_the_inlet_and_alarms
VAR b : FB_Bench; s : FB_Started; i : INT; END_VAR
s(b := b, InitLevel := 95.0);
ADVANCE(T#100ms);
b(Init := TRUE, InitLevel := 95.0);
ASSERT_FALSE(b.st.InletValve);
ASSERT_FALSE(b.st.LampAlarm);
FOR i := 1 TO 12 DO
    ADVANCE(T#100ms);
    b(Init := TRUE, InitLevel := 95.0);
END_FOR;
ASSERT_TRUE(b.st.LampAlarm);
(* acknowledged but still high: the lamp stays *)
b(Init := TRUE, InitLevel := 95.0, ResetBtn := TRUE);
ASSERT_TRUE(b.st.LampAlarm);
(* back to normal *)
FOR i := 1 TO 3 DO
    ADVANCE(T#100ms);
    b(Init := TRUE, InitLevel := 80.0, ResetBtn := FALSE);
END_FOR;
ASSERT_FALSE(b.st.LampAlarm);
END_TEST

TEST station_manual_mode
VAR b : FB_Bench; END_VAR
b(Init := TRUE, InitLevel := 50.0);
b(Init := FALSE, ReqManual := TRUE);
ASSERT_TRUE(b.st.Mode = RB_MODE#Manual);
b(ReqManual := FALSE, ManPump := TRUE, ManInlet := TRUE);
ASSERT_TRUE(b.st.Pump);
ASSERT_TRUE(b.st.InletValve);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopped);
(* Start is ignored outside Auto *)
b(StartBtn := TRUE, ManPump := FALSE, ManInlet := FALSE);
ASSERT_FALSE(b.st.Pump);
b(StartBtn := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
b(StartBtn := TRUE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Idle);
b(StartBtn := FALSE, ReqOff := TRUE, ManPump := TRUE);
ASSERT_FALSE(b.st.Pump);
END_TEST

TEST station_high_level_switch_overrides_the_level_control
VAR b : FB_Bench; s : FB_Started; i : INT; END_VAR
(* the controller wants to fill up to 98 %, the high switch is at 90 % *)
s(b := b, InitLevel := 85.0);
FOR i := 1 TO 40 DO
    ADVANCE(T#100ms);
    b(LevelSP := 97.0);
END_FOR;
ASSERT_FALSE(b.st.InletValve);
ASSERT_TRUE(b.st.Level < 92.0);
END_TEST

TEST station_new_start_begins_a_new_batch
VAR b : FB_Bench; s : FB_Started; i : INT; k : INT; END_VAR
s(b := b, InitLevel := 70.0, BatchSize := 1);
FOR i := 1 TO 45 DO
    ADVANCE(T#100ms);
    b(Container := TRUE);
END_FOR;
FOR i := 1 TO 5 DO
    ADVANCE(T#100ms);
    b(Container := FALSE);
END_FOR;
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopped);
ASSERT_EQ(UDINT#1, b.st.Filled);
b(ResetBtn := TRUE);
b(ResetBtn := FALSE);
b(StartBtn := TRUE);
b(StartBtn := FALSE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Execute);
ASSERT_EQ(UDINT#0, b.st.Filled);
END_TEST
