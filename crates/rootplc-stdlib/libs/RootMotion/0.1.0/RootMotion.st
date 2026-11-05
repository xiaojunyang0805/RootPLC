(* RootMotion 0.1.0: single-axis motion on a virtual axis (spec/13-motion.md).
   Function-block names follow the industry-standard PLCopen motion names;
   behaviour and code are RootPLC's own (clean-room). Apache-2.0. *)

TYPE
    MC_AXIS_STATE : (Disabled, Standstill, Homing, DiscreteMotion, ContinuousMotion, Stopping, ErrorStop);
    MC_DIRECTION : (Positive, Negative);
    (* What the axis cycle does with the setpoint: hold, go to a position,
       hold a velocity, or brake to zero. *)
    RP_AXIS_MODE : (Hold, ToPosition, AtVelocity, Brake);
    AXIS_REF : STRUCT
        (* configuration, set by the program before use *)
        CycleTime       : LREAL := 0.001;    (* seconds per call of RP_VirtualAxis *)
        MaxVelocity     : LREAL := 1000.0;   (* units per second *)
        LimitsEnabled   : BOOL := FALSE;
        PositiveLimit   : LREAL := 0.0;
        NegativeLimit   : LREAL := 0.0;
        (* state, written by the RootMotion blocks only *)
        State           : MC_AXIS_STATE := MC_AXIS_STATE#Disabled;
        Homed           : BOOL;
        Position        : LREAL;             (* setpoint = actual on a virtual axis *)
        Velocity        : LREAL;
        ErrorID         : UDINT;
        Mode            : RP_AXIS_MODE := RP_AXIS_MODE#Hold;
        Target          : LREAL;             (* position, or velocity in mode AtVelocity *)
        VelocityLimit   : LREAL;
        Acceleration    : LREAL;
        Deceleration    : LREAL;
        CommandID       : UDINT;             (* the command in control of the axis *)
        CommandDone     : BOOL;              (* that command has reached its goal *)
    END_STRUCT;
END_TYPE

(* Error IDs ([motion.errors]): 1 not powered, 2 axis in ErrorStop,
   3 invalid parameter, 4 software limit, 5 axis busy (stopping or moving). *)

(* Take control of the axis for a new command ([motion.abort]). *)
FUNCTION RP_TakeAxis : UDINT
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
Axis.CommandID := Axis.CommandID + 1;
Axis.CommandDone := FALSE;
RP_TakeAxis := Axis.CommandID;
END_FUNCTION

(* Why a motion command cannot start, or 0 ([motion.errors]). *)
FUNCTION RP_CanMove : UDINT
VAR_INPUT
    Axis : AXIS_REF;
END_VAR
IF Axis.State = MC_AXIS_STATE#Disabled THEN
    RP_CanMove := UDINT#1;
ELSIF Axis.State = MC_AXIS_STATE#ErrorStop THEN
    RP_CanMove := UDINT#2;
ELSIF Axis.State = MC_AXIS_STATE#Stopping THEN
    RP_CanMove := UDINT#5;
ELSE
    RP_CanMove := 0;
END_IF;
END_FUNCTION

(* Move v towards vDesired, changing it by at most acc (when speeding up) or
   dec (when slowing down) times tc. *)
FUNCTION RP_Approach : LREAL
VAR_INPUT
    v        : LREAL;
    vDesired : LREAL;
    acc      : LREAL;
    dec      : LREAL;
    tc       : LREAL;
END_VAR
VAR
    stepMax : LREAL;
END_VAR
IF ABS(vDesired) > ABS(v) AND (vDesired * v >= 0.0) THEN
    stepMax := acc * tc;
ELSE
    stepMax := dec * tc;
END_IF;
IF vDesired > v THEN
    RP_Approach := MIN(vDesired, v + stepMax);
ELSE
    RP_Approach := MAX(vDesired, v - stepMax);
END_IF;
END_FUNCTION

(* The virtual axis: call it once per cycle, after the motion blocks
   ([motion.cycle], [motion.profile], [motion.limits]). *)
FUNCTION_BLOCK RP_VirtualAxis
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR
    tc       : LREAL;
    remain   : LREAL;
    dir      : LREAL;
    sv       : LREAL;
    svNew    : LREAL;
    rest     : LREAL;
    vStop    : LREAL;
    vDesired : LREAL;
    vNew     : LREAL;
    pNew     : LREAL;
END_VAR
tc := Axis.CycleTime;
IF tc <= 0.0 THEN
    RETURN;
END_IF;
IF Axis.State = MC_AXIS_STATE#Disabled OR Axis.State = MC_AXIS_STATE#ErrorStop THEN
    Axis.Velocity := 0.0;
    RETURN;
END_IF;
vNew := Axis.Velocity;
pNew := Axis.Position;
CASE Axis.Mode OF
RP_AXIS_MODE#ToPosition:
    remain := Axis.Target - Axis.Position;
    IF remain >= 0.0 THEN
        dir := 1.0;
    ELSE
        dir := -1.0;
    END_IF;
    sv := Axis.Velocity * dir;
    IF sv < 0.0 THEN
        (* moving away from the target: brake first *)
        svNew := sv + Axis.Deceleration * tc;
    ELSE
        (* the fastest speed this cycle from which the axis can still stop
           exactly at the target within the deceleration limit *)
        rest := ABS(remain) - sv * tc * 0.5;
        IF rest <= 0.0 THEN
            svNew := 0.0;
        ELSE
            vStop := Axis.Deceleration * (SQRT(tc * tc * 0.25 + 2.0 * rest / Axis.Deceleration) - tc * 0.5);
            svNew := MIN(MIN(MIN(Axis.VelocityLimit, Axis.MaxVelocity), vStop), sv + Axis.Acceleration * tc);
            svNew := MAX(svNew, sv - Axis.Deceleration * tc);
        END_IF;
    END_IF;
    vNew := svNew * dir;
    pNew := Axis.Position + (Axis.Velocity + vNew) * 0.5 * tc;
    IF (Axis.Target - pNew) * dir <= 0.000000001 OR (svNew <= 0.0 AND sv >= 0.0 AND sv <= Axis.Deceleration * tc) THEN
        pNew := Axis.Target;
        vNew := 0.0;
        Axis.Mode := RP_AXIS_MODE#Hold;
        Axis.CommandDone := TRUE;
        Axis.State := MC_AXIS_STATE#Standstill;
    END_IF;
RP_AXIS_MODE#AtVelocity:
    vDesired := Axis.Target;
    IF vDesired > Axis.MaxVelocity THEN
        vDesired := Axis.MaxVelocity;
    ELSIF vDesired < -Axis.MaxVelocity THEN
        vDesired := -Axis.MaxVelocity;
    END_IF;
    vNew := RP_Approach(v := Axis.Velocity, vDesired := vDesired, acc := Axis.Acceleration,
                        dec := Axis.Deceleration, tc := tc);
    pNew := Axis.Position + (Axis.Velocity + vNew) * 0.5 * tc;
    Axis.CommandDone := vNew = vDesired;
RP_AXIS_MODE#Brake:
    vNew := RP_Approach(v := Axis.Velocity, vDesired := 0.0, acc := Axis.Deceleration,
                        dec := Axis.Deceleration, tc := tc);
    pNew := Axis.Position + (Axis.Velocity + vNew) * 0.5 * tc;
    IF vNew = 0.0 THEN
        Axis.Mode := RP_AXIS_MODE#Hold;
        Axis.CommandDone := TRUE;
    END_IF;
ELSE
    vNew := 0.0;
END_CASE;
IF Axis.LimitsEnabled AND (pNew > Axis.PositiveLimit OR pNew < Axis.NegativeLimit) THEN
    IF pNew > Axis.PositiveLimit THEN
        pNew := Axis.PositiveLimit;
    ELSE
        pNew := Axis.NegativeLimit;
    END_IF;
    vNew := 0.0;
    Axis.Mode := RP_AXIS_MODE#Hold;
    Axis.State := MC_AXIS_STATE#ErrorStop;
    Axis.ErrorID := UDINT#4;
END_IF;
Axis.Position := pNew;
Axis.Velocity := vNew;
END_FUNCTION_BLOCK

(* [motion.power] *)
FUNCTION_BLOCK MC_Power
VAR_INPUT
    Enable : BOOL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Status  : BOOL;
    Valid   : BOOL;
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
IF Enable THEN
    IF Axis.State = MC_AXIS_STATE#Disabled THEN
        Axis.State := MC_AXIS_STATE#Standstill;
        Axis.Mode := RP_AXIS_MODE#Hold;
        Axis.Velocity := 0.0;
    END_IF;
ELSIF Axis.State <> MC_AXIS_STATE#ErrorStop THEN
    IF Axis.State <> MC_AXIS_STATE#Disabled THEN
        Axis.CommandID := Axis.CommandID + 1;
    END_IF;
    Axis.State := MC_AXIS_STATE#Disabled;
    Axis.Mode := RP_AXIS_MODE#Hold;
    Axis.Velocity := 0.0;
END_IF;
Status := Axis.State <> MC_AXIS_STATE#Disabled AND Axis.State <> MC_AXIS_STATE#ErrorStop;
Valid := Enable;
Error := Axis.State = MC_AXIS_STATE#ErrorStop;
IF Error THEN
    ErrorID := Axis.ErrorID;
ELSE
    ErrorID := 0;
END_IF;
END_FUNCTION_BLOCK

(* Common output handling of the Execute-started blocks ([motion.execute]):
   results stay while Execute is TRUE; after Execute falls they show for one
   call, then clear. *)
FUNCTION_BLOCK RP_ExecuteOutputs
VAR_INPUT
    Execute : BOOL;
    Busy    : BOOL;
END_VAR
VAR_IN_OUT
    Done           : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
VAR
    shown : BOOL;
END_VAR
IF Busy THEN
    shown := FALSE;
ELSIF NOT Execute AND (Done OR CommandAborted OR Error) THEN
    IF shown THEN
        Done := FALSE;
        CommandAborted := FALSE;
        Error := FALSE;
        ErrorID := 0;
        shown := FALSE;
    ELSE
        shown := TRUE;
    END_IF;
END_IF;
END_FUNCTION_BLOCK

(* [motion.move.absolute] and [motion.move.relative] share this core. *)
FUNCTION_BLOCK RP_MoveTo
VAR_INPUT
    Execute      : BOOL;
    Goal         : LREAL;   (* absolute target position *)
    Velocity     : LREAL;
    Acceleration : LREAL;
    Deceleration : LREAL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Done           : BOOL;
    Busy           : BOOL;
    Active         : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
VAR
    edge  : R_TRIG;
    myID  : UDINT;
    why   : UDINT;
    outs  : RP_ExecuteOutputs;
END_VAR
edge(CLK := Execute);
IF edge.Q THEN
    Done := FALSE;
    CommandAborted := FALSE;
    Error := FALSE;
    ErrorID := 0;
    why := RP_CanMove(Axis := Axis);
    IF why = 0 AND (Velocity <= 0.0 OR Acceleration <= 0.0 OR Deceleration <= 0.0) THEN
        why := UDINT#3;
    END_IF;
    IF why <> 0 THEN
        Error := TRUE;
        ErrorID := why;
        Busy := FALSE;
    ELSE
        myID := RP_TakeAxis(Axis := Axis);
        Axis.Mode := RP_AXIS_MODE#ToPosition;
        Axis.Target := Goal;
        Axis.VelocityLimit := Velocity;
        Axis.Acceleration := Acceleration;
        Axis.Deceleration := Deceleration;
        Axis.State := MC_AXIS_STATE#DiscreteMotion;
        Busy := TRUE;
    END_IF;
ELSIF Busy THEN
    IF Axis.CommandID <> myID THEN
        Busy := FALSE;
        CommandAborted := TRUE;
    ELSIF Axis.State = MC_AXIS_STATE#ErrorStop THEN
        Busy := FALSE;
        Error := TRUE;
        ErrorID := Axis.ErrorID;
    ELSIF Axis.CommandDone THEN
        Busy := FALSE;
        Done := TRUE;
    END_IF;
END_IF;
Active := Busy;
outs(Execute := Execute, Busy := Busy, Done := Done, CommandAborted := CommandAborted,
     Error := Error, ErrorID := ErrorID);
END_FUNCTION_BLOCK

(* [motion.move.absolute] *)
FUNCTION_BLOCK MC_MoveAbsolute
VAR_INPUT
    Execute      : BOOL;
    Position     : LREAL;
    Velocity     : LREAL;
    Acceleration : LREAL;
    Deceleration : LREAL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Done           : BOOL;
    Busy           : BOOL;
    Active         : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
VAR
    core : RP_MoveTo;
END_VAR
core(Execute := Execute, Goal := Position, Velocity := Velocity, Acceleration := Acceleration,
     Deceleration := Deceleration, Axis := Axis);
Done := core.Done;
Busy := core.Busy;
Active := core.Active;
CommandAborted := core.CommandAborted;
Error := core.Error;
ErrorID := core.ErrorID;
END_FUNCTION_BLOCK

(* [motion.move.relative]: the distance is taken from the position at the
   rising edge of Execute. *)
FUNCTION_BLOCK MC_MoveRelative
VAR_INPUT
    Execute      : BOOL;
    Distance     : LREAL;
    Velocity     : LREAL;
    Acceleration : LREAL;
    Deceleration : LREAL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Done           : BOOL;
    Busy           : BOOL;
    Active         : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
VAR
    core  : RP_MoveTo;
    edge  : R_TRIG;
    goal  : LREAL;
END_VAR
edge(CLK := Execute);
IF edge.Q THEN
    goal := Axis.Position + Distance;
END_IF;
core(Execute := Execute, Goal := goal, Velocity := Velocity, Acceleration := Acceleration,
     Deceleration := Deceleration, Axis := Axis);
Done := core.Done;
Busy := core.Busy;
Active := core.Active;
CommandAborted := core.CommandAborted;
Error := core.Error;
ErrorID := core.ErrorID;
END_FUNCTION_BLOCK

(* [motion.move.velocity] *)
FUNCTION_BLOCK MC_MoveVelocity
VAR_INPUT
    Execute      : BOOL;
    Velocity     : LREAL;
    Acceleration : LREAL;
    Deceleration : LREAL;
    Direction    : MC_DIRECTION := MC_DIRECTION#Positive;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    InVelocity     : BOOL;
    Busy           : BOOL;
    Active         : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
VAR
    edge  : R_TRIG;
    myID  : UDINT;
    why   : UDINT;
    outs  : RP_ExecuteOutputs;
    none  : BOOL;
END_VAR
edge(CLK := Execute);
IF edge.Q THEN
    InVelocity := FALSE;
    CommandAborted := FALSE;
    Error := FALSE;
    ErrorID := 0;
    why := RP_CanMove(Axis := Axis);
    IF why = 0 AND (Velocity < 0.0 OR Acceleration <= 0.0 OR Deceleration <= 0.0) THEN
        why := UDINT#3;
    END_IF;
    IF why <> 0 THEN
        Error := TRUE;
        ErrorID := why;
        Busy := FALSE;
    ELSE
        myID := RP_TakeAxis(Axis := Axis);
        Axis.Mode := RP_AXIS_MODE#AtVelocity;
        IF Direction = MC_DIRECTION#Negative THEN
            Axis.Target := -Velocity;
        ELSE
            Axis.Target := Velocity;
        END_IF;
        Axis.Acceleration := Acceleration;
        Axis.Deceleration := Deceleration;
        Axis.State := MC_AXIS_STATE#ContinuousMotion;
        Busy := TRUE;
    END_IF;
ELSIF Busy THEN
    IF Axis.CommandID <> myID THEN
        Busy := FALSE;
        InVelocity := FALSE;
        CommandAborted := TRUE;
    ELSIF Axis.State = MC_AXIS_STATE#ErrorStop THEN
        Busy := FALSE;
        InVelocity := FALSE;
        Error := TRUE;
        ErrorID := Axis.ErrorID;
    ELSE
        InVelocity := Axis.CommandDone;
    END_IF;
END_IF;
Active := Busy;
none := FALSE;
outs(Execute := Execute, Busy := Busy, Done := none, CommandAborted := CommandAborted,
     Error := Error, ErrorID := ErrorID);
END_FUNCTION_BLOCK

(* [motion.stop] and [motion.halt] share this core. Stop holds the axis in
   Stopping while Execute stays TRUE; Halt returns to Standstill. *)
FUNCTION_BLOCK RP_Brake
VAR_INPUT
    Execute      : BOOL;
    Deceleration : LREAL;
    Hold         : BOOL;    (* TRUE for MC_Stop *)
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Done           : BOOL;
    Busy           : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
VAR
    edge : R_TRIG;
    myID : UDINT;
    outs : RP_ExecuteOutputs;
END_VAR
edge(CLK := Execute);
IF edge.Q THEN
    Done := FALSE;
    CommandAborted := FALSE;
    Error := FALSE;
    ErrorID := 0;
    IF Axis.State = MC_AXIS_STATE#Disabled OR Axis.State = MC_AXIS_STATE#ErrorStop THEN
        Error := TRUE;
        IF Axis.State = MC_AXIS_STATE#Disabled THEN
            ErrorID := UDINT#1;
        ELSE
            ErrorID := UDINT#2;
        END_IF;
    ELSIF Deceleration <= 0.0 THEN
        Error := TRUE;
        ErrorID := UDINT#3;
    ELSE
        myID := RP_TakeAxis(Axis := Axis);
        Axis.Mode := RP_AXIS_MODE#Brake;
        Axis.Deceleration := Deceleration;
        IF Hold THEN
            Axis.State := MC_AXIS_STATE#Stopping;
        ELSE
            Axis.State := MC_AXIS_STATE#DiscreteMotion;
        END_IF;
        Busy := TRUE;
    END_IF;
ELSIF Busy THEN
    IF Axis.CommandID <> myID THEN
        Busy := FALSE;
        CommandAborted := TRUE;
    ELSIF Axis.State = MC_AXIS_STATE#ErrorStop THEN
        Busy := FALSE;
        Error := TRUE;
        ErrorID := Axis.ErrorID;
    ELSIF Axis.CommandDone THEN
        Busy := FALSE;
        Done := TRUE;
        IF NOT Hold THEN
            Axis.State := MC_AXIS_STATE#Standstill;
        END_IF;
    END_IF;
END_IF;
(* MC_Stop: the axis leaves Stopping only after Done and Execute FALSE *)
IF Hold AND NOT Busy AND NOT Execute AND Axis.State = MC_AXIS_STATE#Stopping
   AND Axis.CommandID = myID THEN
    Axis.State := MC_AXIS_STATE#Standstill;
END_IF;
outs(Execute := Execute, Busy := Busy, Done := Done, CommandAborted := CommandAborted,
     Error := Error, ErrorID := ErrorID);
END_FUNCTION_BLOCK

(* [motion.stop] *)
FUNCTION_BLOCK MC_Stop
VAR_INPUT
    Execute      : BOOL;
    Deceleration : LREAL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Done           : BOOL;
    Busy           : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
VAR
    core : RP_Brake;
END_VAR
core(Execute := Execute, Deceleration := Deceleration, Hold := TRUE, Axis := Axis);
Done := core.Done;
Busy := core.Busy;
CommandAborted := core.CommandAborted;
Error := core.Error;
ErrorID := core.ErrorID;
END_FUNCTION_BLOCK

(* [motion.halt] *)
FUNCTION_BLOCK MC_Halt
VAR_INPUT
    Execute      : BOOL;
    Deceleration : LREAL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Done           : BOOL;
    Busy           : BOOL;
    Active         : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
VAR
    core : RP_Brake;
END_VAR
core(Execute := Execute, Deceleration := Deceleration, Hold := FALSE, Axis := Axis);
Done := core.Done;
Busy := core.Busy;
Active := core.Busy;
CommandAborted := core.CommandAborted;
Error := core.Error;
ErrorID := core.ErrorID;
END_FUNCTION_BLOCK

(* [motion.home]: on a virtual axis homing sets the position at once. *)
FUNCTION_BLOCK MC_Home
VAR_INPUT
    Execute  : BOOL;
    Position : LREAL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Done           : BOOL;
    Busy           : BOOL;
    Active         : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
VAR
    edge : R_TRIG;
    why  : UDINT;
    outs : RP_ExecuteOutputs;
END_VAR
edge(CLK := Execute);
IF edge.Q THEN
    Done := FALSE;
    CommandAborted := FALSE;
    Error := FALSE;
    ErrorID := 0;
    why := RP_CanMove(Axis := Axis);
    IF why = 0 AND Axis.State <> MC_AXIS_STATE#Standstill THEN
        why := UDINT#5;
    END_IF;
    IF why <> 0 THEN
        Error := TRUE;
        ErrorID := why;
    ELSE
        RP_TakeAxis(Axis := Axis);
        Axis.Position := Position;
        Axis.Velocity := 0.0;
        Axis.Mode := RP_AXIS_MODE#Hold;
        Axis.Homed := TRUE;
        Axis.State := MC_AXIS_STATE#Standstill;
        Done := TRUE;
    END_IF;
END_IF;
Busy := FALSE;
Active := FALSE;
outs(Execute := Execute, Busy := Busy, Done := Done, CommandAborted := CommandAborted,
     Error := Error, ErrorID := ErrorID);
END_FUNCTION_BLOCK

(* [motion.reset] *)
FUNCTION_BLOCK MC_Reset
VAR_INPUT
    Execute : BOOL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Done    : BOOL;
    Busy    : BOOL;
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    edge  : R_TRIG;
    outs  : RP_ExecuteOutputs;
    none  : BOOL;
END_VAR
edge(CLK := Execute);
IF edge.Q THEN
    Done := FALSE;
    Error := FALSE;
    ErrorID := 0;
    IF Axis.State = MC_AXIS_STATE#ErrorStop THEN
        Axis.State := MC_AXIS_STATE#Standstill;
        Axis.ErrorID := 0;
        Axis.Velocity := 0.0;
        Axis.Mode := RP_AXIS_MODE#Hold;
    END_IF;
    Done := TRUE;
END_IF;
Busy := FALSE;
none := FALSE;
outs(Execute := Execute, Busy := Busy, Done := Done, CommandAborted := none,
     Error := Error, ErrorID := ErrorID);
END_FUNCTION_BLOCK

(* [motion.read] *)
FUNCTION_BLOCK MC_ReadActualPosition
VAR_INPUT
    Enable : BOOL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Valid    : BOOL;
    Position : LREAL;
END_VAR
Valid := Enable;
IF Enable THEN
    Position := Axis.Position;
END_IF;
END_FUNCTION_BLOCK

(* [motion.read] *)
FUNCTION_BLOCK MC_ReadStatus
VAR_INPUT
    Enable : BOOL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Valid            : BOOL;
    Disabled         : BOOL;
    ErrorStop        : BOOL;
    Stopping         : BOOL;
    Homing           : BOOL;
    Standstill       : BOOL;
    DiscreteMotion   : BOOL;
    ContinuousMotion : BOOL;
END_VAR
Valid := Enable;
Disabled := Enable AND Axis.State = MC_AXIS_STATE#Disabled;
ErrorStop := Enable AND Axis.State = MC_AXIS_STATE#ErrorStop;
Stopping := Enable AND Axis.State = MC_AXIS_STATE#Stopping;
Homing := Enable AND Axis.State = MC_AXIS_STATE#Homing;
Standstill := Enable AND Axis.State = MC_AXIS_STATE#Standstill;
DiscreteMotion := Enable AND Axis.State = MC_AXIS_STATE#DiscreteMotion;
ContinuousMotion := Enable AND Axis.State = MC_AXIS_STATE#ContinuousMotion;
END_FUNCTION_BLOCK
