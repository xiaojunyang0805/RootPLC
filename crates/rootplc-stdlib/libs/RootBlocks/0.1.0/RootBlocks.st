(* RootBlocks 0.1.0: typical PLC blocks with common conventions
   (spec/15-blocks.md). Cards: blocks/cards/. Apache-2.0. *)

TYPE
    (* [blocks.mode] *)
    RB_MODE : (Off, Manual, Auto);
    (* [blocks.status]: the same status for every device module *)
    RB_DEVICE_STATUS : STRUCT
        Mode      : RB_MODE;
        Commanded : BOOL;     (* the block drives the device on / open *)
        Active    : BOOL;     (* the feedback says on / open *)
        Error     : BOOL;
        ErrorID   : UDINT;
        Starts    : UDINT;    (* switch-ons since the block started *)
    END_STRUCT;
END_TYPE

(* F04.VALVE.ONOFF: an on/off valve with open and closed feedback.
   ErrorID 1 did not open in time, 2 did not close in time, 3 both feedback
   signals TRUE. Safe state: output de-energised (valve closed). *)
FUNCTION_BLOCK RB_ValveOnOff
VAR_INPUT
    Mode         : RB_MODE := RB_MODE#Off;
    AutoOpen     : BOOL;              (* automatic command *)
    ManOpen      : BOOL;              (* manual command *)
    Interlock    : BOOL;              (* TRUE: close now, in every mode *)
    Permissive   : BOOL := TRUE;      (* FALSE: do not open *)
    FbOpen       : BOOL;              (* open limit switch *)
    FbClosed     : BOOL;              (* closed limit switch *)
    Feedback     : BOOL := TRUE;      (* FALSE: no limit switches fitted *)
    FeedbackTime : TIME := T#5s;
    Reset        : BOOL;              (* rising edge clears a fault *)
END_VAR
VAR_OUTPUT
    Open     : BOOL;                  (* actuator output *)
    IsOpen   : BOOL;
    IsClosed : BOOL;
    Error    : BOOL;
    ErrorID  : UDINT;
    Status   : RB_DEVICE_STATUS;
END_VAR
VAR
    resetEdge : R_TRIG;
    want      : BOOL;
    tMismatch : TON;
    tConflict : TON;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
CASE Mode OF
RB_MODE#Auto:
    want := AutoOpen;
RB_MODE#Manual:
    want := ManOpen;
ELSE
    want := FALSE;
END_CASE;
(* a permissive is needed to open, not to stay open *)
IF want AND NOT Open AND NOT Permissive THEN
    want := FALSE;
END_IF;
IF Interlock OR Error THEN
    want := FALSE;
END_IF;
IF want AND NOT Open THEN
    Status.Starts := Status.Starts + 1;
END_IF;
Open := want;
IF Feedback THEN
    tConflict(IN := FbOpen AND FbClosed, PT := FeedbackTime);
    tMismatch(IN := (Open AND NOT FbOpen) OR (NOT Open AND NOT FbClosed), PT := FeedbackTime);
    IF NOT Error THEN
        IF tConflict.Q THEN
            Error := TRUE;
            ErrorID := UDINT#3;
        ELSIF tMismatch.Q THEN
            Error := TRUE;
            IF Open THEN
                ErrorID := UDINT#1;
            ELSE
                ErrorID := UDINT#2;
            END_IF;
        END_IF;
    END_IF;
    IsOpen := FbOpen AND NOT FbClosed;
    IsClosed := FbClosed AND NOT FbOpen;
ELSE
    tConflict(IN := FALSE, PT := FeedbackTime);
    tMismatch(IN := FALSE, PT := FeedbackTime);
    IsOpen := Open;
    IsClosed := NOT Open;
END_IF;
IF Error THEN
    Open := FALSE;
END_IF;
Status.Mode := Mode;
Status.Commanded := Open;
Status.Active := IsOpen;
Status.Error := Error;
Status.ErrorID := ErrorID;
END_FUNCTION_BLOCK

(* F01.SCALE: linear scaling of a raw value to engineering units, with range
   supervision. ErrorID 1 invalid range (RawMin = RawMax), 2 below range
   (for example a broken 4-20 mA wire), 3 above range. Safe state: Value
   keeps the last valid value. *)
FUNCTION_BLOCK RB_Scale
VAR_INPUT
    Raw    : REAL;
    RawMin : REAL := 0.0;
    RawMax : REAL := 100.0;
    EngMin : REAL := 0.0;
    EngMax : REAL := 100.0;
    Margin : REAL := 0.0;     (* raw tolerance outside the range before a fault *)
    Clamp  : BOOL := TRUE;    (* keep Value within EngMin .. EngMax *)
    Reset  : BOOL;            (* rising edge clears a fault *)
END_VAR
VAR_OUTPUT
    Value   : REAL;
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    resetEdge : R_TRIG;
    lo        : REAL;
    hi        : REAL;
    v         : REAL;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
lo := MIN(RawMin, RawMax);
hi := MAX(RawMin, RawMax);
IF NOT Error THEN
    IF RawMax = RawMin THEN
        Error := TRUE;
        ErrorID := UDINT#1;
    ELSIF Raw < lo - Margin THEN
        Error := TRUE;
        ErrorID := UDINT#2;
    ELSIF Raw > hi + Margin THEN
        Error := TRUE;
        ErrorID := UDINT#3;
    END_IF;
END_IF;
IF NOT Error THEN
    v := EngMin + (Raw - RawMin) * (EngMax - EngMin) / (RawMax - RawMin);
    IF Clamp THEN
        v := LIMIT(MIN(EngMin, EngMax), v, MAX(EngMin, EngMax));
    END_IF;
    Value := v;
END_IF;
END_FUNCTION_BLOCK

(* F04.MOTOR.DOL: a motor started direct on line through one contactor,
   with running feedback, an overload input and a restart delay.
   ErrorID 1 no running feedback after a start, 2 running feedback without a
   command (contactor stuck), 3 overload. Safe state: contactor off. *)
FUNCTION_BLOCK RB_Motor
VAR_INPUT
    Mode         : RB_MODE := RB_MODE#Off;
    AutoRun      : BOOL;
    ManRun       : BOOL;
    Interlock    : BOOL;              (* TRUE: stop now, in every mode *)
    Permissive   : BOOL := TRUE;      (* FALSE: do not start *)
    FbRunning    : BOOL;              (* contactor auxiliary contact *)
    Overload     : BOOL;              (* TRUE: thermal overload tripped *)
    Feedback     : BOOL := TRUE;      (* FALSE: no running feedback wired *)
    FeedbackTime : TIME := T#2s;
    RestartDelay : TIME := T#0s;      (* minimum time off before a start *)
    Reset        : BOOL;
END_VAR
VAR_OUTPUT
    Run     : BOOL;                   (* contactor output *)
    Running : BOOL;
    Error   : BOOL;
    ErrorID : UDINT;
    Status  : RB_DEVICE_STATUS;
END_VAR
VAR
    resetEdge : R_TRIG;
    want      : BOOL;
    tOff      : TON;
    tMismatch : TON;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
IF Overload AND NOT Error THEN
    Error := TRUE;
    ErrorID := UDINT#3;
END_IF;
CASE Mode OF
RB_MODE#Auto:
    want := AutoRun;
RB_MODE#Manual:
    want := ManRun;
ELSE
    want := FALSE;
END_CASE;
tOff(IN := NOT Run, PT := RestartDelay);
IF want AND NOT Run AND (NOT Permissive OR NOT tOff.Q) THEN
    want := FALSE;
END_IF;
IF Interlock OR Error THEN
    want := FALSE;
END_IF;
IF want AND NOT Run THEN
    Status.Starts := Status.Starts + 1;
END_IF;
Run := want;
IF Feedback THEN
    tMismatch(IN := Run XOR FbRunning, PT := FeedbackTime);
    IF tMismatch.Q AND NOT Error THEN
        Error := TRUE;
        IF Run THEN
            ErrorID := UDINT#1;
        ELSE
            ErrorID := UDINT#2;
        END_IF;
    END_IF;
    Running := FbRunning;
ELSE
    tMismatch(IN := FALSE, PT := FeedbackTime);
    Running := Run;
END_IF;
IF Error THEN
    Run := FALSE;
END_IF;
(* the restart delay counts from the moment the contactor drops *)
tOff(IN := NOT Run, PT := RestartDelay);
Status.Mode := Mode;
Status.Commanded := Run;
Status.Active := Running;
Status.Error := Error;
Status.ErrorID := ErrorID;
END_FUNCTION_BLOCK

(* F04.MOTOR.REV: a reversing motor with two contactors (forward,
   reverse), never both on, with a dead time between directions.
   ErrorID 1 no feedback for the commanded direction, 2 feedback without a
   command, 3 overload, 4 both feedback contacts on. Safe state: both
   contactors off. *)
FUNCTION_BLOCK RB_MotorReversing
VAR_INPUT
    Mode         : RB_MODE := RB_MODE#Off;
    AutoFwd      : BOOL;
    AutoRev      : BOOL;
    ManFwd       : BOOL;
    ManRev       : BOOL;
    Interlock    : BOOL;
    Permissive   : BOOL := TRUE;
    FbFwd        : BOOL;
    FbRev        : BOOL;
    Overload     : BOOL;
    Feedback     : BOOL := TRUE;
    FeedbackTime : TIME := T#2s;
    ReverseDelay : TIME := T#1s;      (* both contactors off at least this long between directions *)
    Reset        : BOOL;
END_VAR
VAR_OUTPUT
    RunFwd     : BOOL;
    RunRev     : BOOL;
    RunningFwd : BOOL;
    RunningRev : BOOL;
    Error      : BOOL;
    ErrorID    : UDINT;
    Status     : RB_DEVICE_STATUS;
END_VAR
VAR
    resetEdge : R_TRIG;
    f         : BOOL;
    r         : BOOL;
    tDead     : TON;
    tFwd      : TON;
    tRev      : TON;
    tBoth     : TON;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
IF Overload AND NOT Error THEN
    Error := TRUE;
    ErrorID := UDINT#3;
END_IF;
CASE Mode OF
RB_MODE#Auto:
    f := AutoFwd;
    r := AutoRev;
RB_MODE#Manual:
    f := ManFwd;
    r := ManRev;
ELSE
    f := FALSE;
    r := FALSE;
END_CASE;
(* both directions at once: stop *)
IF f AND r THEN
    f := FALSE;
    r := FALSE;
END_IF;
tDead(IN := NOT RunFwd AND NOT RunRev, PT := ReverseDelay);
IF f AND NOT RunFwd AND (NOT Permissive OR NOT tDead.Q) THEN
    f := FALSE;
END_IF;
IF r AND NOT RunRev AND (NOT Permissive OR NOT tDead.Q) THEN
    r := FALSE;
END_IF;
IF Interlock OR Error THEN
    f := FALSE;
    r := FALSE;
END_IF;
IF (f AND NOT RunFwd) OR (r AND NOT RunRev) THEN
    Status.Starts := Status.Starts + 1;
END_IF;
RunFwd := f;
RunRev := r;
IF Feedback THEN
    tBoth(IN := FbFwd AND FbRev, PT := FeedbackTime);
    tFwd(IN := RunFwd XOR FbFwd, PT := FeedbackTime);
    tRev(IN := RunRev XOR FbRev, PT := FeedbackTime);
    IF NOT Error THEN
        IF tBoth.Q THEN
            Error := TRUE;
            ErrorID := UDINT#4;
        ELSIF (tFwd.Q AND RunFwd) OR (tRev.Q AND RunRev) THEN
            Error := TRUE;
            ErrorID := UDINT#1;
        ELSIF tFwd.Q OR tRev.Q THEN
            Error := TRUE;
            ErrorID := UDINT#2;
        END_IF;
    END_IF;
    RunningFwd := FbFwd AND NOT FbRev;
    RunningRev := FbRev AND NOT FbFwd;
ELSE
    tBoth(IN := FALSE, PT := FeedbackTime);
    tFwd(IN := FALSE, PT := FeedbackTime);
    tRev(IN := FALSE, PT := FeedbackTime);
    RunningFwd := RunFwd;
    RunningRev := RunRev;
END_IF;
IF Error THEN
    RunFwd := FALSE;
    RunRev := FALSE;
END_IF;
(* the dead time counts from the moment both contactors are off *)
tDead(IN := NOT RunFwd AND NOT RunRev, PT := ReverseDelay);
Status.Mode := Mode;
Status.Commanded := RunFwd OR RunRev;
Status.Active := RunningFwd OR RunningRev;
Status.Error := Error;
Status.ErrorID := ErrorID;
END_FUNCTION_BLOCK

(* F04.CYLINDER: a pneumatic cylinder, double-acting (two solenoids) or
   single-acting (one solenoid, spring return), with end-position switches.
   ErrorID 1 did not extend in time, 2 did not retract in time, 3 both end
   switches on. Safe state: both solenoids off. *)
FUNCTION_BLOCK RB_Cylinder
VAR_INPUT
    Mode         : RB_MODE := RB_MODE#Off;
    AutoExtend   : BOOL;              (* TRUE extended, FALSE retracted *)
    ManExtend    : BOOL;
    Interlock    : BOOL;              (* TRUE: both solenoids off now *)
    Permissive   : BOOL := TRUE;      (* FALSE: do not extend *)
    FbExtended   : BOOL;
    FbRetracted  : BOOL;
    DoubleActing : BOOL := TRUE;      (* FALSE: spring return, Retract unused *)
    Feedback     : BOOL := TRUE;
    MoveTime     : TIME := T#3s;      (* supervision time for a stroke *)
    Reset        : BOOL;
END_VAR
VAR_OUTPUT
    Extend      : BOOL;               (* solenoid A *)
    Retract     : BOOL;               (* solenoid B (double-acting only) *)
    IsExtended  : BOOL;
    IsRetracted : BOOL;
    Error       : BOOL;
    ErrorID     : UDINT;
    Status      : RB_DEVICE_STATUS;
END_VAR
VAR
    resetEdge : R_TRIG;
    want      : BOOL;
    active    : BOOL;
    tMove     : TON;
    tBoth     : TON;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
active := Mode <> RB_MODE#Off AND NOT Interlock;
want := (Mode = RB_MODE#Auto AND AutoExtend) OR (Mode = RB_MODE#Manual AND ManExtend);
IF want AND NOT Extend AND NOT Permissive THEN
    want := FALSE;
END_IF;
IF NOT active OR Error THEN
    want := FALSE;
END_IF;
IF want AND NOT Extend THEN
    Status.Starts := Status.Starts + 1;
END_IF;
Extend := want;
Retract := DoubleActing AND active AND NOT Error AND NOT want;
IF Feedback THEN
    tBoth(IN := FbExtended AND FbRetracted, PT := MoveTime);
    tMove(IN := (Extend AND NOT FbExtended) OR (Retract AND NOT FbRetracted)
               OR (NOT DoubleActing AND NOT Extend AND active AND NOT FbRetracted), PT := MoveTime);
    IF NOT Error THEN
        IF tBoth.Q THEN
            Error := TRUE;
            ErrorID := UDINT#3;
        ELSIF tMove.Q THEN
            Error := TRUE;
            IF Extend THEN
                ErrorID := UDINT#1;
            ELSE
                ErrorID := UDINT#2;
            END_IF;
        END_IF;
    END_IF;
    IsExtended := FbExtended AND NOT FbRetracted;
    IsRetracted := FbRetracted AND NOT FbExtended;
ELSE
    tBoth(IN := FALSE, PT := MoveTime);
    tMove(IN := FALSE, PT := MoveTime);
    IsExtended := Extend;
    IsRetracted := NOT Extend;
END_IF;
IF Error THEN
    Extend := FALSE;
    Retract := FALSE;
END_IF;
Status.Mode := Mode;
Status.Commanded := Extend;
Status.Active := IsExtended;
Status.Error := Error;
Status.ErrorID := ErrorID;
END_FUNCTION_BLOCK

(* F04.PUMP: a pump driven by RB_Motor, with dry-run protection.
   ErrorID 1-3 as RB_Motor (no running feedback, contactor stuck, overload),
   4 dry run while running. Safe state: motor off. *)
FUNCTION_BLOCK RB_Pump
VAR_INPUT
    Mode         : RB_MODE := RB_MODE#Off;
    AutoRun      : BOOL;
    ManRun       : BOOL;
    Interlock    : BOOL;
    Permissive   : BOOL := TRUE;
    FbRunning    : BOOL;
    Overload     : BOOL;
    DryRun       : BOOL;              (* TRUE: no liquid (level or flow switch) *)
    DryRunTime   : TIME := T#10s;     (* dry run while running this long: fault 4 *)
    Feedback     : BOOL := TRUE;
    FeedbackTime : TIME := T#2s;
    RestartDelay : TIME := T#0s;
    Reset        : BOOL;
END_VAR
VAR_OUTPUT
    Run     : BOOL;
    Running : BOOL;
    Error   : BOOL;
    ErrorID : UDINT;
    Status  : RB_DEVICE_STATUS;
END_VAR
VAR
    motor     : RB_Motor;
    resetEdge : R_TRIG;
    dry       : BOOL;
    tDry      : TON;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    dry := FALSE;
END_IF;
motor(Mode := Mode, AutoRun := AutoRun, ManRun := ManRun, Interlock := Interlock OR dry,
      Permissive := Permissive, FbRunning := FbRunning, Overload := Overload, Feedback := Feedback,
      FeedbackTime := FeedbackTime, RestartDelay := RestartDelay, Reset := Reset);
tDry(IN := motor.Running AND DryRun, PT := DryRunTime);
IF tDry.Q AND NOT dry AND NOT motor.Error THEN
    dry := TRUE;
    motor(Mode := Mode, AutoRun := AutoRun, ManRun := ManRun, Interlock := TRUE,
          Permissive := Permissive, FbRunning := FbRunning, Overload := Overload, Feedback := Feedback,
          FeedbackTime := FeedbackTime, RestartDelay := RestartDelay, Reset := Reset);
END_IF;
Run := motor.Run;
Running := motor.Running;
Error := motor.Error OR dry;
IF motor.Error THEN
    ErrorID := motor.ErrorID;
ELSIF dry THEN
    ErrorID := UDINT#4;
ELSE
    ErrorID := 0;
END_IF;
Status := motor.Status;
Status.Error := Error;
Status.ErrorID := ErrorID;
END_FUNCTION_BLOCK
