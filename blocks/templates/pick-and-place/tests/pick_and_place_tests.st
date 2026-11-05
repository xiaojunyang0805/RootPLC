(* Tests of the pick-and-place template against a simulated cell. One bench
   call = one 20 ms PLC cycle. A part arrives at the pick position 25 cycles
   after the last one was taken; the vacuum holds a part when the gripper
   switches it on at the pick position; a part set down at the place
   position is taken away after 25 cycles. *)
FUNCTION_BLOCK FB_CellSim
VAR_INPUT
    Vacuum    : BOOL;
    X, Z      : LREAL;
    PickX     : LREAL := 100.0;
    PlaceX    : LREAL := 500.0;
    PickZ     : LREAL := 80.0;
    PlaceZ    : LREAL := 60.0;
    NoGrip    : BOOL;                  (* worn suction cup: no vacuum *)
    Drop      : BOOL;                  (* the part falls off *)
    HoldPlace : BOOL;                  (* the placed part is not taken away *)
END_VAR
VAR_OUTPUT
    PartAtPick : BOOL;
    PlaceFree  : BOOL := TRUE;
    VacuumOk   : BOOL;
    Delivered  : INT;
    Dropped    : INT;
END_VAR
VAR
    partHere  : BOOL := TRUE;
    gripped   : BOOL;
    placeFull : BOOL;
    feedT     : INT;
    placeT    : INT;
    offT      : INT;                   (* cycles since the vacuum went off *)
END_VAR
IF NOT partHere THEN
    feedT := feedT + 1;
    IF feedT >= 25 THEN
        partHere := TRUE;
        feedT := 0;
    END_IF;
END_IF;
IF Vacuum AND NOT gripped AND partHere AND ABS(X - PickX) < 1.0 AND ABS(Z - PickZ) < 1.0 THEN
    gripped := TRUE;
    partHere := FALSE;
END_IF;
IF Drop AND gripped THEN
    gripped := FALSE;
    Dropped := Dropped + 1;
END_IF;
(* the part comes off 5 cycles (100 ms) after the vacuum went off; lifted
   earlier, it is dragged away and lost *)
IF Vacuum THEN
    offT := 0;
ELSIF gripped THEN
    offT := offT + 1;
    IF ABS(X - PlaceX) < 1.0 AND ABS(Z - PlaceZ) < 1.0 AND NOT placeFull THEN
        IF offT >= 5 THEN
            gripped := FALSE;
            placeFull := TRUE;
            placeT := 0;
            Delivered := Delivered + 1;
        END_IF;
    ELSE
        gripped := FALSE;
        Dropped := Dropped + 1;
    END_IF;
END_IF;
IF placeFull AND NOT HoldPlace THEN
    placeT := placeT + 1;
    IF placeT >= 25 THEN
        placeFull := FALSE;
    END_IF;
END_IF;
PartAtPick := partHere;
PlaceFree := NOT placeFull;
VacuumOk := Vacuum AND gripped AND NOT NoGrip;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_CellBench
VAR_INPUT
    ReqAuto, ReqManual, ReqOff : BOOL;
    StartBtn, StopBtn, ResetBtn : BOOL;
    EStopOk   : BOOL := TRUE;
    NoGrip    : BOOL;
    Drop      : BOOL;
    HoldPlace : BOOL;
    LimitX    : BOOL;                  (* soft limit at 400 mm on X *)
END_VAR
VAR
    sim        : FB_CellSim;
    pp         : FB_PickPlace;
    axX        : AXIS_REF;
    axZ        : AXIS_REF;
    configured : BOOL;
    xWhileDown : BOOL;                 (* X moved with Z below the safe height *)
END_VAR
IF NOT configured THEN
    axX.CycleTime := 0.02;
    axZ.CycleTime := 0.02;
    configured := TRUE;
END_IF;
axX.LimitsEnabled := LimitX;
axX.PositiveLimit := 400.0;
axX.NegativeLimit := -10.0;
sim(Vacuum := pp.Vacuum, X := axX.Position, Z := axZ.Position,
    NoGrip := NoGrip, Drop := Drop, HoldPlace := HoldPlace);
pp(ReqAuto := ReqAuto, ReqManual := ReqManual, ReqOff := ReqOff,
   StartBtn := StartBtn, StopBtn := StopBtn, ResetBtn := ResetBtn, EStopOk := EStopOk,
   PartAtPick := sim.PartAtPick, PlaceFree := sim.PlaceFree, VacuumOk := sim.VacuumOk,
   AxisX := axX, AxisZ := axZ);
RP_VirtualAxis(Axis := axX);
RP_VirtualAxis(Axis := axZ);
xWhileDown := xWhileDown OR (axX.Velocity <> 0.0 AND axZ.Position > 0.5);
END_FUNCTION_BLOCK

(* Auto, reset (homes the axes), start: the cell is producing *)
FUNCTION_BLOCK FB_CellStarted
VAR_IN_OUT
    b : FB_CellBench;
END_VAR
b(ReqAuto := TRUE);
b(ReqAuto := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
b();
b(StartBtn := TRUE);
b(StartBtn := FALSE);
END_FUNCTION_BLOCK

TEST cell_places_a_part
VAR b : FB_CellBench; s : FB_CellStarted; i, inGrip, inRelease : INT; END_VAR
b();
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Stopped);
ASSERT_TRUE(b.axX.State = MC_AXIS_STATE#Disabled);
s(b := b);
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Execute);
ASSERT_TRUE(b.axX.Homed AND b.axZ.Homed);
ASSERT_TRUE(b.pp.LampRunning);
FOR i := 1 TO 500 DO
    ADVANCE(T#20ms);
    b();
    IF b.pp.StepNo = 4 THEN inGrip := inGrip + 1; END_IF;
    IF b.pp.StepNo = 8 THEN inRelease := inRelease + 1; END_IF;
    IF b.pp.Placed = UDINT#1 THEN EXIT; END_IF;
END_FOR;
ASSERT_EQ(UDINT#1, b.pp.Placed);
(* the grip waits for the debounced vacuum; the release takes 200 ms *)
ASSERT_TRUE(inGrip >= 2 AND inGrip <= 5);
ASSERT_TRUE(inRelease >= 10 AND inRelease <= 11);
ASSERT_EQ(9, b.pp.StepNo);
FOR i := 1 TO 10 DO ADVANCE(T#20ms); b(); END_FOR;
ASSERT_EQ(1, b.sim.Delivered);
ASSERT_EQ(0, b.sim.Dropped);
ASSERT_FALSE(b.xWhileDown);
ASSERT_TRUE(ABS(b.axZ.Position) < 0.001);
ASSERT_TRUE(ABS(b.axX.Position - 500.0) < 0.001);
ASSERT_FALSE(b.pp.Vacuum);
ASSERT_FALSE(b.pp.LampFault);
END_TEST

TEST cell_keeps_cycling
VAR b : FB_CellBench; s : FB_CellStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 2000 DO
    ADVANCE(T#20ms);
    b();
    IF b.sim.Delivered = 3 THEN EXIT; END_IF;
END_FOR;
ASSERT_EQ(3, b.sim.Delivered);
ASSERT_EQ(0, b.sim.Dropped);
ASSERT_FALSE(b.xWhileDown);
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Execute);
END_TEST

TEST cell_waits_for_a_free_place
VAR b : FB_CellBench; s : FB_CellStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 600 DO
    ADVANCE(T#20ms);
    b(HoldPlace := TRUE);
END_FOR;
(* one part delivered; the next waits at the pick position *)
ASSERT_EQ(1, b.sim.Delivered);
ASSERT_EQ(1, b.pp.StepNo);
ASSERT_TRUE(b.sim.PartAtPick);
ASSERT_FALSE(b.pp.Vacuum);
FOR i := 1 TO 600 DO
    ADVANCE(T#20ms);
    b(HoldPlace := FALSE);
    IF b.sim.Delivered = 2 THEN EXIT; END_IF;
END_FOR;
ASSERT_EQ(2, b.sim.Delivered);
END_TEST

TEST cell_aborts_when_the_grip_fails
VAR b : FB_CellBench; s : FB_CellStarted; i, inGrip : INT; END_VAR
s(b := b);
FOR i := 1 TO 300 DO
    ADVANCE(T#20ms);
    b(NoGrip := TRUE);
    IF b.pp.StepNo = 4 THEN inGrip := inGrip + 1; END_IF;
    IF b.pp.State = RB_MACHINE_STATE#Aborted THEN EXIT; END_IF;
END_FOR;
(* 2 s in the grip step: 100 cycles *)
ASSERT_TRUE(inGrip >= 99 AND inGrip <= 101);
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Aborted);
ASSERT_TRUE(b.pp.LampFault);
ASSERT_TRUE(b.pp.Mode = RB_MODE#Off);
ASSERT_FALSE(b.pp.Vacuum);
ASSERT_TRUE(b.axZ.State = MC_AXIS_STATE#Disabled);
ASSERT_EQ(0, b.pp.StepNo);
END_TEST

TEST cell_aborts_when_the_part_drops
VAR b : FB_CellBench; s : FB_CellStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 500 DO
    ADVANCE(T#20ms);
    b(Drop := b.pp.StepNo = 6);
    IF b.pp.State = RB_MACHINE_STATE#Aborted THEN EXIT; END_IF;
END_FOR;
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Aborted);
ASSERT_EQ(1, b.sim.Dropped);
ASSERT_FALSE(b.pp.Vacuum);
ASSERT_TRUE(b.axX.State = MC_AXIS_STATE#Disabled);
(* clear the abort, then reset: the axes are homed again *)
b(Drop := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Stopped);
ASSERT_FALSE(b.pp.LampFault);
b(ReqAuto := TRUE);
b(ReqAuto := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
b();
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Idle);
ASSERT_TRUE(ABS(b.axX.Position) < 0.001);
END_TEST

TEST cell_stop_finishes_the_part
VAR b : FB_CellBench; s : FB_CellStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 300 DO
    ADVANCE(T#20ms);
    b();
    IF b.pp.StepNo = 2 THEN EXIT; END_IF;
END_FOR;
b(StopBtn := TRUE);
b(StopBtn := FALSE);
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Stopping);
FOR i := 1 TO 500 DO
    ADVANCE(T#20ms);
    b();
    IF b.pp.State = RB_MACHINE_STATE#Stopped THEN EXIT; END_IF;
END_FOR;
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Stopped);
FOR i := 1 TO 30 DO ADVANCE(T#20ms); b(); END_FOR;
ASSERT_EQ(1, b.sim.Delivered);
ASSERT_EQ(0, b.sim.Dropped);
ASSERT_TRUE(ABS(b.axZ.Position) < 0.001);
ASSERT_EQ(0, b.pp.StepNo);
END_TEST

TEST cell_emergency_stop
VAR b : FB_CellBench; s : FB_CellStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 300 DO
    ADVANCE(T#20ms);
    b();
    IF b.pp.StepNo = 6 THEN EXIT; END_IF;
END_FOR;
b(EStopOk := FALSE);
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Aborted);
ASSERT_FALSE(b.pp.Vacuum);
ADVANCE(T#20ms);
b();
ASSERT_TRUE(b.axX.State = MC_AXIS_STATE#Disabled);
ASSERT_TRUE(b.axX.Velocity = 0.0);
END_TEST

TEST cell_does_not_start_outside_auto
VAR b : FB_CellBench; i : INT; END_VAR
b(ReqManual := TRUE);
b(ReqManual := FALSE, ResetBtn := TRUE);
b(ResetBtn := FALSE);
b();
b(StartBtn := TRUE);
b(StartBtn := FALSE);
FOR i := 1 TO 50 DO ADVANCE(T#20ms); b(); END_FOR;
ASSERT_FALSE(b.pp.State = RB_MACHINE_STATE#Execute);
ASSERT_TRUE(ABS(b.axX.Position) < 0.001);
ASSERT_EQ(0, b.pp.StepNo);
END_TEST

TEST cell_aborts_on_a_drop_while_lifting_or_lowering
VAR b, c : FB_CellBench; s : FB_CellStarted; i : INT; END_VAR
s(b := b);
FOR i := 1 TO 500 DO
    ADVANCE(T#20ms);
    b(Drop := b.pp.StepNo = 5);
    IF b.pp.State = RB_MACHINE_STATE#Aborted THEN EXIT; END_IF;
END_FOR;
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Aborted);
ASSERT_EQ(1, b.sim.Dropped);
(* aborted while lifting, before X moved towards the place *)
ASSERT_TRUE(ABS(b.axX.Position - 100.0) < 0.001);
s(b := c);
FOR i := 1 TO 500 DO
    ADVANCE(T#20ms);
    c(Drop := c.pp.StepNo = 7);
    IF c.pp.State = RB_MACHINE_STATE#Aborted THEN EXIT; END_IF;
END_FOR;
ASSERT_TRUE(c.pp.State = RB_MACHINE_STATE#Aborted);
ASSERT_EQ(1, c.sim.Dropped);
END_TEST

TEST cell_aborts_on_an_axis_error
VAR b : FB_CellBench; s : FB_CellStarted; i, errAt : INT; END_VAR
s(b := b);
(* the place position lies beyond X's soft limit *)
FOR i := 1 TO 500 DO
    ADVANCE(T#20ms);
    b(LimitX := TRUE);
    IF errAt = 0 AND b.axX.State = MC_AXIS_STATE#ErrorStop THEN errAt := i; END_IF;
    IF b.pp.State = RB_MACHINE_STATE#Aborted THEN EXIT; END_IF;
END_FOR;
(* the axis error aborts in the next cycle, not after a step timeout *)
ASSERT_TRUE(errAt > 0 AND i - errAt <= 1);
ASSERT_TRUE(b.pp.State = RB_MACHINE_STATE#Aborted);
ASSERT_TRUE(b.axX.State = MC_AXIS_STATE#ErrorStop);
ASSERT_FALSE(b.pp.Vacuum);
ASSERT_TRUE(b.pp.Mode = RB_MODE#Off);
END_TEST
