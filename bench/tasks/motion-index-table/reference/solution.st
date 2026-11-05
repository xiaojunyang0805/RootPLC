FUNCTION_BLOCK FB_IndexTable
VAR_INPUT
    enable : BOOL;
    home   : BOOL;
    next   : BOOL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    station    : INT;
    inPosition : BOOL;
    error      : BOOL;
END_VAR
VAR
    power   : MC_Power;
    homing  : MC_Home;
    stepMove    : MC_MoveRelative;
    nextUp  : R_TRIG;
    doStep  : BOOL;
    moving  : BOOL;
END_VAR

power(Enable := enable, Axis := Axis);
homing(Execute := home AND enable, Position := 0.0, Axis := Axis);
IF homing.Done THEN
    station := 0;
END_IF;

nextUp(CLK := next);
IF nextUp.Q AND enable AND Axis.Homed AND NOT moving THEN
    doStep := TRUE;
    moving := TRUE;
    station := (station + 1) MOD 4;
END_IF;
stepMove(Execute := doStep, Distance := 90.0, Velocity := 180.0, Acceleration := 720.0,
     Deceleration := 720.0, Axis := Axis);
IF stepMove.Done OR stepMove.Error OR stepMove.CommandAborted OR NOT enable THEN
    doStep := FALSE;
    moving := FALSE;
END_IF;

error := power.Error OR homing.Error OR stepMove.Error;
inPosition := enable AND Axis.Homed AND NOT moving AND Axis.State = MC_AXIS_STATE#Standstill;

RP_VirtualAxis(Axis := Axis);
END_FUNCTION_BLOCK
