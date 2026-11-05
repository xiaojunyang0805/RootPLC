(* Tests of the conveyor-line template against a simulated conveyor. One
   bench call = one 100 ms PLC cycle. A part needs 10 cycles of running to
   reach the eye at the zone end and covers it for 5 more cycles while it
   moves on, which it does only when the next zone is empty (or, at the
   last zone, when the outfeed is free). *)
FUNCTION_BLOCK FB_ConveyorSim
VAR_INPUT
    Motor       : ARRAY[1..3] OF BOOL;
    OutfeedFree : BOOL;
    AddPart     : BOOL;                 (* rising edge: a part enters zone 1 *)
    JamZone     : INT;                  (* 1..3: the part there cannot leave *)
END_VAR
VAR_OUTPUT
    Eye      : ARRAY[1..3] OF BOOL;
    MotorFb  : ARRAY[1..3] OF BOOL;
    OutCount : INT;
END_VAR
VAR
    part   : ARRAY[1..3] OF BOOL;
    pos    : ARRAY[1..3] OF INT;
    add    : R_TRIG;
    i      : INT;
    nextFree : BOOL;
END_VAR
FOR i := 3 TO 1 BY -1 DO
    IF part[i] AND MotorFb[i] THEN
        IF i = 3 THEN
            nextFree := OutfeedFree;
        ELSE
            nextFree := NOT part[i + 1];
        END_IF;
        IF pos[i] < 10 THEN
            pos[i] := pos[i] + 1;
        ELSIF JamZone <> i AND nextFree THEN
            (* the part covers the eye for 5 cycles while it moves on *)
            pos[i] := pos[i] + 1;
            IF pos[i] >= 15 THEN
                part[i] := FALSE;
                IF i = 3 THEN
                    OutCount := OutCount + 1;
                ELSE
                    part[i + 1] := TRUE;
                    pos[i + 1] := 0;
                END_IF;
            END_IF;
        END_IF;
    END_IF;
END_FOR;
add(CLK := AddPart);
IF add.Q AND NOT part[1] THEN
    part[1] := TRUE;
    pos[1] := 0;
END_IF;
FOR i := 1 TO 3 DO
    Eye[i] := part[i] AND pos[i] >= 10;
    MotorFb[i] := Motor[i];
END_FOR;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_LineBench
VAR_INPUT
    ReqAuto, ReqManual, ReqOff : BOOL;
    StartBtn, StopBtn, ResetBtn, ManJog : BOOL;
    EStopOk     : BOOL := TRUE;
    OutfeedFree : BOOL := TRUE;
    AddPart     : BOOL;
    JamZone     : INT;
END_VAR
VAR
    sim  : FB_ConveyorSim;
    line : FB_ConveyorLine;
    none : ARRAY[1..3] OF BOOL;
END_VAR
sim(Motor := line.Motor, OutfeedFree := OutfeedFree, AddPart := AddPart, JamZone := JamZone);
line(ReqAuto := ReqAuto, ReqManual := ReqManual, ReqOff := ReqOff,
     StartBtn := StartBtn, StopBtn := StopBtn, ResetBtn := ResetBtn, ManJog := ManJog,
     EStopOk := EStopOk, Eye := sim.Eye, MotorFb := sim.MotorFb, Overload := none,
     OutfeedFree := OutfeedFree, InfeedFeeding := AddPart);
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_LineStarted
VAR_OUTPUT
    Ok : BOOL;
END_VAR
VAR_IN_OUT
    b : FB_LineBench;
END_VAR
b(ReqAuto := TRUE);
b(ReqAuto := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
b(StartBtn := TRUE);
b(StartBtn := FALSE);
Ok := b.line.State = RB_MACHINE_STATE#Execute;
END_FUNCTION_BLOCK

TEST line_carries_a_part_to_the_outfeed
VAR b : FB_LineBench; s : FB_LineStarted; i : INT; END_VAR
s(b := b);
ASSERT_TRUE(s.Ok);
ASSERT_TRUE(b.line.LampRunning);
b(AddPart := TRUE);
b(AddPart := FALSE);
FOR i := 1 TO 60 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_EQ(1, b.sim.OutCount);
ASSERT_EQ(UDINT#1, b.line.Delivered);
ASSERT_FALSE(b.line.LampFault);
END_TEST

TEST line_accumulates_without_pressure
VAR b : FB_LineBench; s : FB_LineStarted; i : INT; k : INT; END_VAR
s(b := b);
FOR k := 1 TO 3 DO
    b(AddPart := TRUE, OutfeedFree := FALSE);
    b(AddPart := FALSE, OutfeedFree := FALSE);
    FOR i := 1 TO 40 DO ADVANCE(T#100ms); b(); END_FOR;
END_FOR;
(* one part waits at the end of each zone, every motor stopped *)
ASSERT_TRUE(b.sim.Eye[1] AND b.sim.Eye[2] AND b.sim.Eye[3]);
ASSERT_FALSE(b.line.Motor[1] OR b.line.Motor[2] OR b.line.Motor[3]);
ASSERT_EQ(0, b.sim.OutCount);
ASSERT_FALSE(b.line.LampFault);
(* the next machine is ready: all three leave in order *)
b(OutfeedFree := TRUE);
FOR i := 1 TO 60 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_EQ(3, b.sim.OutCount);
ASSERT_EQ(UDINT#3, b.line.Delivered);
END_TEST

TEST line_jam_aborts
VAR b : FB_LineBench; s : FB_LineStarted; i : INT; END_VAR
s(b := b);
b(AddPart := TRUE, JamZone := 2);
b(AddPart := FALSE, JamZone := 2);
FOR i := 1 TO 40 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.line.State = RB_MACHINE_STATE#Execute);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.line.State = RB_MACHINE_STATE#Aborted);
ASSERT_TRUE(b.line.LampFault);
ASSERT_FALSE(b.line.Motor[1] OR b.line.Motor[2] OR b.line.Motor[3]);
ASSERT_TRUE(b.line.Mode = RB_MODE#Off);
(* jam cleared by hand, reset: back to Stopped *)
b(JamZone := 0, ResetBtn := TRUE);
b(ResetBtn := FALSE);
ASSERT_TRUE(b.line.State = RB_MACHINE_STATE#Stopped);
ASSERT_FALSE(b.line.LampFault);
END_TEST

TEST line_emergency_stop_and_stop
VAR b : FB_LineBench; s : FB_LineStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 2 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.line.Motor[1]);
b(StopBtn := TRUE);
ASSERT_TRUE(b.line.State = RB_MACHINE_STATE#Stopping);
b(StopBtn := FALSE);
ASSERT_TRUE(b.line.State = RB_MACHINE_STATE#Stopped);
ASSERT_FALSE(b.line.Motor[1]);
ASSERT_FALSE(b.line.LampRunning);
b(ResetBtn := TRUE);
b(ResetBtn := FALSE);
b(StartBtn := TRUE);
b(StartBtn := FALSE);
ASSERT_TRUE(b.line.State = RB_MACHINE_STATE#Execute);
b(EStopOk := FALSE);
ASSERT_TRUE(b.line.State = RB_MACHINE_STATE#Aborted);
ASSERT_FALSE(b.line.Motor[1] OR b.line.Motor[2] OR b.line.Motor[3]);
ASSERT_TRUE(b.line.LampFault);
END_TEST

TEST line_manual_jog
VAR b : FB_LineBench; END_VAR
b(ReqManual := TRUE);
b(ReqManual := FALSE, ManJog := TRUE);
ASSERT_TRUE(b.line.Motor[1] AND b.line.Motor[2] AND b.line.Motor[3]);
b(ManJog := FALSE);
ASSERT_FALSE(b.line.Motor[1] OR b.line.Motor[2] OR b.line.Motor[3]);
(* Start is ignored outside Auto *)
b(ResetBtn := TRUE);
b(ResetBtn := FALSE);
b(StartBtn := TRUE);
ASSERT_TRUE(b.line.State = RB_MACHINE_STATE#Idle);
END_TEST

TEST line_empty_zones_go_to_sleep
VAR b : FB_LineBench; s : FB_LineStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 50 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.line.Motor[1]);
FOR i := 1 TO 60 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_FALSE(b.line.Motor[1] OR b.line.Motor[2] OR b.line.Motor[3]);
ASSERT_TRUE(b.line.LampRunning);
(* a new part wakes zone 1; the others wake as it is handed on *)
b(AddPart := TRUE);
FOR i := 1 TO 2 DO ADVANCE(T#100ms); b(); END_FOR;
ASSERT_TRUE(b.line.Motor[1]);
END_TEST
