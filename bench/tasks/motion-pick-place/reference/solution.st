FUNCTION_BLOCK FB_PickPlace
VAR_INPUT
    enable  : BOOL;
    home    : BOOL;
    start   : BOOL;
    reset   : BOOL;
    gripped : BOOL;
END_VAR
VAR_IN_OUT
    AxisX : AXIS_REF;
    AxisZ : AXIS_REF;
END_VAR
VAR_OUTPUT
    gripper : BOOL;
    busy    : BOOL;
    parts   : UDINT;
    error   : BOOL;
END_VAR
VAR
    powerX, powerZ : MC_Power;
    homeX, homeZ   : MC_Home;
    resetX, resetZ : MC_Reset;
    zDown, zUp     : MC_MoveAbsolute;
    xPlace, xPick  : MC_MoveAbsolute;
    startUp        : R_TRIG;
    resetUp        : R_TRIG;
    seq            : INT;
    stopped        : BOOL;
END_VAR

resetX(Execute := reset AND enable, Axis := AxisX);
resetZ(Execute := reset AND enable, Axis := AxisZ);
powerX(Enable := enable, Axis := AxisX);
powerZ(Enable := enable, Axis := AxisZ);
homeX(Execute := home AND enable, Position := 0.0, Axis := AxisX);
homeZ(Execute := home AND enable, Position := 0.0, Axis := AxisZ);
startUp(CLK := start);
resetUp(CLK := reset);

IF resetUp.Q AND enable THEN
    stopped := FALSE;
END_IF;
IF NOT enable THEN
    seq := 0;
END_IF;

IF seq = 0 AND startUp.Q AND enable AND NOT stopped AND AxisX.Homed AND AxisZ.Homed THEN
    seq := 1;
END_IF;

zUp(Execute := seq = 1 OR seq = 5 OR seq = 9, Position := 0.0, Velocity := 200.0,
    Acceleration := 2000.0, Deceleration := 2000.0, Axis := AxisZ);
xPick(Execute := seq = 2 OR seq = 10, Position := 0.0, Velocity := 500.0,
      Acceleration := 2000.0, Deceleration := 2000.0, Axis := AxisX);
zDown(Execute := seq = 3 OR seq = 7, Position := 50.0, Velocity := 200.0,
      Acceleration := 2000.0, Deceleration := 2000.0, Axis := AxisZ);
xPlace(Execute := seq = 6, Position := 300.0, Velocity := 500.0,
       Acceleration := 2000.0, Deceleration := 2000.0, Axis := AxisX);

CASE seq OF
    1: IF zUp.Done THEN seq := 2; END_IF;
    2: IF xPick.Done THEN seq := 3; END_IF;
    3: IF zDown.Done THEN seq := 4; END_IF;
    4: gripper := TRUE;
       IF gripped THEN seq := 5; END_IF;
    5: IF zUp.Done THEN seq := 6; END_IF;
    6: IF xPlace.Done THEN seq := 7; END_IF;
    7: IF zDown.Done THEN seq := 8; END_IF;
    8: gripper := FALSE;
       IF NOT gripped THEN seq := 9; END_IF;
    9: IF zUp.Done THEN seq := 10; END_IF;
    10: IF xPick.Done THEN
            seq := 0;
            parts := parts + 1;
        END_IF;
END_CASE;

(* every move error here comes with ErrorStop, which MC_Power reports *)
IF powerX.Error OR powerZ.Error THEN
    seq := 0;
    stopped := TRUE;
END_IF;
error := stopped;
busy := seq <> 0;

RP_VirtualAxis(Axis := AxisX);
RP_VirtualAxis(Axis := AxisZ);
END_FUNCTION_BLOCK
