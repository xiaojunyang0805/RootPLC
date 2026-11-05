FUNCTION_BLOCK FB_JogAxis
VAR_INPUT
    enable : BOOL;
    jogPos : BOOL;
    jogNeg : BOOL;
    reset  : BOOL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    moving  : BOOL;
    fault   : BOOL;
    errorID : UDINT;
END_VAR
VAR
    power   : MC_Power;
    fwd     : MC_MoveVelocity;
    back    : MC_MoveVelocity;
    halt    : MC_Halt;
    clear   : MC_Reset;
END_VAR

power(Enable := enable, Axis := Axis);
clear(Execute := reset AND enable, Axis := Axis);

fwd(Execute := enable AND jogPos AND NOT jogNeg, Velocity := 50.0,
    Acceleration := 200.0, Deceleration := 200.0, Direction := MC_DIRECTION#Positive, Axis := Axis);
back(Execute := enable AND jogNeg AND NOT jogPos, Velocity := 50.0,
     Acceleration := 200.0, Deceleration := 200.0, Direction := MC_DIRECTION#Negative, Axis := Axis);
halt(Execute := enable AND NOT (jogPos XOR jogNeg), Deceleration := 400.0, Axis := Axis);

RP_VirtualAxis(Axis := Axis);

fault := Axis.State = MC_AXIS_STATE#ErrorStop;
errorID := Axis.ErrorID;
moving := Axis.Velocity <> 0.0;
END_FUNCTION_BLOCK
