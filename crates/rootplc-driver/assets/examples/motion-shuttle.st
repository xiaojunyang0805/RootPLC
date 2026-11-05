(* title: Motion: shuttle between two positions on one axis
   tags: motion, axis, servo, MC_Power, MC_Home, MC_MoveAbsolute, RootMotion, PLCopen
   description: A shuttle axis powers up, homes, then moves to a load or unload position with MC_MoveAbsolute (trapezoid profile). The virtual axis lets the TEST check timing, speed and the final position before a real drive is connected.
   libraries: RootMotion *)
PROGRAM EX_Shuttle
VAR_INPUT
    run        : BOOL;     (* power the shuttle *)
    goUnload   : BOOL;     (* TRUE: unload position, FALSE: load position *)
END_VAR
VAR_OUTPUT
    atLoad, atUnload : BOOL;
    failed           : BOOL;
END_VAR
VAR
    shuttle  : AXIS_REF;   (* mm *)
    enableAx : MC_Power;
    reference : MC_Home;
    toLoad   : MC_MoveAbsolute;
    toUnload : MC_MoveAbsolute;
END_VAR
shuttle.CycleTime := 0.01; (* this program runs every 10 ms *)
enableAx(Enable := run, Axis := shuttle);
reference(Execute := enableAx.Status, Position := 0.0, Axis := shuttle);
toUnload(Execute := run AND shuttle.Homed AND goUnload, Position := 500.0,
         Velocity := 250.0, Acceleration := 1000.0, Deceleration := 1000.0, Axis := shuttle);
toLoad(Execute := run AND shuttle.Homed AND NOT goUnload, Position := 0.0,
       Velocity := 250.0, Acceleration := 1000.0, Deceleration := 1000.0, Axis := shuttle);
RP_VirtualAxis(Axis := shuttle);
atUnload := toUnload.Done;
atLoad := shuttle.Homed AND NOT goUnload AND shuttle.State = MC_AXIS_STATE#Standstill
          AND ABS(shuttle.Position) < 0.001;
failed := enableAx.Error; (* the axis is in ErrorStop, e.g. after a software limit *)
END_PROGRAM

TEST ex_shuttle_unload_and_back
VAR uut : EX_Shuttle; i : INT; arrived : INT := -1; END_VAR
uut(run := TRUE);
uut(run := TRUE);
ASSERT_TRUE(uut.atLoad);
FOR i := 1 TO 300 DO
    uut(run := TRUE, goUnload := TRUE);
    ASSERT_TRUE(uut.shuttle.Velocity <= 250.0001);
    IF uut.atUnload AND arrived < 0 THEN arrived := i; END_IF;
END_FOR;
(* 0.25 s up + 1.75 s cruise + 0.25 s down = 2.25 s, Done one cycle later *)
ASSERT_TRUE(arrived >= 225 AND arrived <= 228);
ASSERT_TRUE(ABS(uut.shuttle.Position - 500.0) < 0.000001);
FOR i := 1 TO 300 DO uut(run := TRUE, goUnload := FALSE); END_FOR;
ASSERT_TRUE(uut.atLoad);
ASSERT_FALSE(uut.failed);
END_TEST

TEST ex_shuttle_off_stops_the_axis
VAR uut : EX_Shuttle; i : INT; END_VAR
uut(run := TRUE);
FOR i := 1 TO 50 DO uut(run := TRUE, goUnload := TRUE); END_FOR;
uut(run := FALSE, goUnload := TRUE);
ASSERT_TRUE(uut.shuttle.State = MC_AXIS_STATE#Disabled);
ASSERT_TRUE(uut.shuttle.Velocity = 0.0);
ASSERT_FALSE(uut.atUnload);
END_TEST

TEST ex_shuttle_flags_only_when_true
VAR uut : EX_Shuttle; i : INT; END_VAR
FOR i := 1 TO 5 DO uut(run := FALSE); END_FOR;
ASSERT_FALSE(uut.atLoad);
ASSERT_FALSE(uut.failed);
uut(run := TRUE);
FOR i := 1 TO 20 DO uut(run := TRUE, goUnload := TRUE); END_FOR;
ASSERT_FALSE(uut.atLoad);
ASSERT_FALSE(uut.atUnload);
(* a software limit before the unload position stops the axis with an error *)
uut.shuttle.LimitsEnabled := TRUE;
uut.shuttle.PositiveLimit := 400.0;
uut.shuttle.NegativeLimit := -10.0;
FOR i := 1 TO 300 DO uut(run := TRUE, goUnload := TRUE); END_FOR;
ASSERT_TRUE(uut.failed);
ASSERT_FALSE(uut.atUnload);
ASSERT_TRUE(uut.shuttle.Position <= 400.0);
FOR i := 1 TO 300 DO uut(run := TRUE, goUnload := FALSE); END_FOR;
ASSERT_FALSE(uut.atLoad);
END_TEST
