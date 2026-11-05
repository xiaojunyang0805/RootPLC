(* Tests of the pump-station template against a simulated hydraulic system.
   One bench call = one 100 ms PLC cycle. Each pump at speed s (%) would
   give 0.07 * s bar; the pressure follows the stronger pump with a lag. *)
FUNCTION_BLOCK FB_HydraulicSim
VAR_INPUT
    Run         : ARRAY[1..2] OF BOOL;
    Speed       : ARRAY[1..2] OF REAL;
    Fault       : ARRAY[1..2] OF BOOL;   (* inject a drive fault *)
    StuckHigh   : BOOL;                  (* the pressure transmitter reads 9.5 bar *)
END_VAR
VAR_OUTPUT
    PressureRaw : REAL;
    Ready       : ARRAY[1..2] OF BOOL;
    Running     : ARRAY[1..2] OF BOOL;
    Actual      : ARRAY[1..2] OF REAL;
END_VAR
VAR
    p      : REAL;
    target : REAL;
    i      : INT;
END_VAR
target := 0.0;
FOR i := 1 TO 2 DO
    IF Running[i] THEN
        target := MAX(target, 0.07 * Actual[i]);
    END_IF;
END_FOR;
p := p + (target - p) * 0.3;
FOR i := 1 TO 2 DO
    Ready[i] := NOT Fault[i];
    Running[i] := Run[i] AND NOT Fault[i];
    IF Running[i] THEN
        Actual[i] := Speed[i];
    ELSE
        Actual[i] := 0.0;
    END_IF;
END_FOR;
IF StuckHigh THEN
    PressureRaw := 9.5 * 2764.8;
ELSE
    PressureRaw := p * 2764.8;
END_IF;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_StationBench
VAR_INPUT
    ReqAuto, ReqManual, ReqOff : BOOL;
    StartBtn, StopBtn, ResetBtn : BOOL;
    ManRun    : ARRAY[1..2] OF BOOL;
    EStopOk   : BOOL := TRUE;
    SuctionOk : BOOL := TRUE;
    Fault     : ARRAY[1..2] OF BOOL;
    StuckHigh : BOOL;
END_VAR
VAR
    sim : FB_HydraulicSim;
    st  : FB_PumpStation;
END_VAR
sim(Run := st.Run, Speed := st.Speed, Fault := Fault, StuckHigh := StuckHigh);
st(ReqAuto := ReqAuto, ReqManual := ReqManual, ReqOff := ReqOff,
   StartBtn := StartBtn, StopBtn := StopBtn, ResetBtn := ResetBtn, ManRun := ManRun,
   EStopOk := EStopOk, PressureRaw := sim.PressureRaw, SuctionOk := SuctionOk,
   DriveReady := sim.Ready, DriveRunning := sim.Running, DriveFault := Fault,
   ActualSpeed := sim.Actual);
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_StationStarted
VAR_OUTPUT
    Ok : BOOL;
END_VAR
VAR_IN_OUT
    b : FB_StationBench;
END_VAR
b(ReqAuto := TRUE);
b(ReqAuto := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
b(StartBtn := TRUE);
b(StartBtn := FALSE);
Ok := b.st.State = RB_MACHINE_STATE#Execute;
END_FUNCTION_BLOCK

TEST station_holds_the_pressure_with_one_pump
VAR b : FB_StationBench; s : FB_StationStarted; i : INT; END_VAR
s(b := b);
ASSERT_TRUE(s.Ok);
FOR i := 1 TO 300 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(ABS(b.st.Pressure - 4.0) < 0.2);
ASSERT_EQ(1, b.st.Duty);
ASSERT_TRUE(b.st.Run[1]);
ASSERT_FALSE(b.st.Run[2]);
(* about 4 bar / 0.07 = 57 % *)
ASSERT_TRUE(b.st.Speed[1] > 50.0 AND b.st.Speed[1] < 65.0);
ASSERT_TRUE(b.st.Hours[1] > 0.0);
ASSERT_FALSE(b.st.LampAlarm);
ASSERT_TRUE(b.st.LampRunning);
END_TEST

TEST station_alternates_by_run_hours
VAR b : FB_StationBench; s : FB_StationStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_EQ(1, b.st.Duty);
b(StopBtn := TRUE);
b(StopBtn := FALSE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopped);
ASSERT_FALSE(b.st.Run[1]);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); b(); END_FOR;
(* pump 1 has more hours now: pump 2 is duty at the next start *)
b(ResetBtn := TRUE);
b(ResetBtn := FALSE);
b(StartBtn := TRUE);
b(StartBtn := FALSE);
ASSERT_EQ(2, b.st.Duty);
(* the controller did not wind up while stopped *)
b();
ASSERT_TRUE(b.st.Speed[2] < 95.0);
FOR i := 1 TO 5 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.st.Run[2]);
ASSERT_FALSE(b.st.Run[1]);
END_TEST

TEST station_standby_takes_over_a_failed_drive
VAR b : FB_StationBench; s : FB_StationStarted; i : INT; f : ARRAY[1..2] OF BOOL; END_VAR
s(b := b);
FOR i := 1 TO 100 DO ADVANCE(T#100ms); b(); END_FOR;
f[1] := TRUE;
b(Fault := f);
FOR i := 1 TO 300 DO ADVANCE(T#100ms); b(Fault := f); END_FOR;
ASSERT_EQ(2, b.st.Duty);
ASSERT_TRUE(b.st.Run[2]);
ASSERT_FALSE(b.st.Run[1]);
ASSERT_TRUE(ABS(b.st.Pressure - 4.0) < 0.2);
ASSERT_TRUE(b.st.LampAlarm);
ASSERT_FALSE(b.st.LampFault);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Execute);
(* the second drive fails too: the station aborts (in the next cycle) *)
f[2] := TRUE;
b(Fault := f);
ASSERT_FALSE(b.st.Run[1] OR b.st.Run[2]);
b(Fault := f);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Aborted);
ASSERT_TRUE(b.st.LampFault);
ASSERT_FALSE(b.st.Run[1] OR b.st.Run[2]);
END_TEST

TEST station_low_suction_stops_and_resumes
VAR b : FB_StationBench; s : FB_StationStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); b(); END_FOR;
FOR i := 1 TO 10 DO ADVANCE(T#100ms); b(SuctionOk := FALSE); END_FOR;
ASSERT_FALSE(b.st.Run[1] OR b.st.Run[2]);
ASSERT_TRUE(b.st.LampAlarm);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Execute);
(* water back: the pumps resume; the alarm waits for acknowledgement *)
FOR i := 1 TO 10 DO ADVANCE(T#100ms); b(SuctionOk := TRUE); END_FOR;
ASSERT_TRUE(b.st.Run[1] OR b.st.Run[2]);
ASSERT_TRUE(b.st.LampAlarm);
b(ResetBtn := TRUE);
ASSERT_FALSE(b.st.LampAlarm);
END_TEST

TEST station_high_pressure_stops_the_pumps
VAR b : FB_StationBench; s : FB_StationStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); b(); END_FOR;
FOR i := 1 TO 20 DO ADVANCE(T#100ms); b(StuckHigh := TRUE); END_FOR;
ASSERT_FALSE(b.st.Run[1] OR b.st.Run[2]);
ASSERT_TRUE(b.st.LampAlarm);
ASSERT_TRUE(b.st.Pressure > 8.0);
(* the reading returns to normal: the lamp stays until acknowledged *)
FOR i := 1 TO 30 DO ADVANCE(T#100ms); b(StuckHigh := FALSE); END_FOR;
ASSERT_TRUE(b.st.LampAlarm);
b(ResetBtn := TRUE);
ASSERT_FALSE(b.st.LampAlarm);
END_TEST

TEST station_emergency_stop_and_manual
VAR b : FB_StationBench; s : FB_StationStarted; i : INT; m : ARRAY[1..2] OF BOOL; END_VAR
s(b := b);
FOR i := 1 TO 20 DO ADVANCE(T#100ms); b(); END_FOR;
b(EStopOk := FALSE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Aborted);
ASSERT_FALSE(b.st.Run[1] OR b.st.Run[2]);
ASSERT_TRUE(b.st.Mode = RB_MODE#Off);
b(EStopOk := TRUE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Stopped);
b(ReqManual := TRUE);
m[2] := TRUE;
b(ReqManual := FALSE, ManRun := m);
ASSERT_TRUE(b.st.Run[2]);
ASSERT_FALSE(b.st.Run[1]);
ASSERT_TRUE(ABS(b.st.Speed[2] - 50.0) < 0.001);
END_TEST

TEST station_standby_drive_fault_only_alarms
VAR b : FB_StationBench; s : FB_StationStarted; i : INT; f : ARRAY[1..2] OF BOOL; END_VAR
s(b := b);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); b(); END_FOR;
f[2] := TRUE;
FOR i := 1 TO 10 DO ADVANCE(T#100ms); b(Fault := f); END_FOR;
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Execute);
ASSERT_EQ(1, b.st.Duty);
ASSERT_TRUE(b.st.Run[1]);
ASSERT_TRUE(b.st.LampAlarm);
ASSERT_FALSE(b.st.LampFault);
END_TEST

TEST station_duty_drive_failing_at_start
VAR b : FB_StationBench; s : FB_StationStarted; i : INT; f : ARRAY[1..2] OF BOOL; END_VAR
(* equal hours: pump 1 is chosen, but its drive fails at once *)
f[1] := TRUE;
b(Fault := f);
s(b := b);
FOR i := 1 TO 20 DO ADVANCE(T#100ms); b(Fault := f); END_FOR;
ASSERT_EQ(2, b.st.Duty);
ASSERT_TRUE(b.st.Run[2]);
ASSERT_TRUE(b.st.State = RB_MACHINE_STATE#Execute);
END_TEST
