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
    (* F08: alarm states, named as in ISA-18.2 *)
    RB_ALARM_STATE : (Normal, ActiveUnack, ActiveAcked, ReturnedUnack);
    (* F05: batch phase states (ISA-88 names; transient states omitted) *)
    RB_PHASE_STATE : (Idle, Running, Held, Complete, Stopped, Aborted);
    (* F10: machine states, a subset of the PackML state model (public names) *)
    RB_MACHINE_STATE : (Stopped, Resetting, Idle, Starting, Execute, Stopping, Held, Aborted);
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

(* F04.DRIVE: command and status of a variable-speed drive (VFD), mapped by
   the application to the drive's control and status word or its I/O. The
   drive ramps; the block clamps the set point.
   ErrorID 1 no running feedback after a start, 2 running without a
   command, 3 the drive reports a fault, 4 speed deviation (when
   SpeedTolerance > 0). Safe state: Run off, set point 0. *)
FUNCTION_BLOCK RB_Drive
VAR_INPUT
    Mode           : RB_MODE := RB_MODE#Off;
    AutoRun        : BOOL;
    AutoSpeed      : REAL;            (* set point, e.g. % or Hz *)
    AutoReverse    : BOOL;
    ManRun         : BOOL;
    ManSpeed       : REAL;
    ManReverse     : BOOL;
    Interlock      : BOOL;
    Permissive     : BOOL := TRUE;
    DriveReady     : BOOL;            (* drive status: ready to run *)
    DriveRunning   : BOOL;            (* drive status: running *)
    DriveFault     : BOOL;            (* drive status: fault *)
    ActualSpeed    : REAL;
    SpeedMin       : REAL := 0.0;
    SpeedMax       : REAL := 100.0;
    SpeedTolerance : REAL := 0.0;     (* 0: no speed supervision *)
    FeedbackTime   : TIME := T#5s;    (* run feedback and speed deviation *)
    Reset          : BOOL;
END_VAR
VAR_OUTPUT
    Run           : BOOL;
    Reverse       : BOOL;
    SpeedSetpoint : REAL;
    ResetDrive    : BOOL;             (* one-call pulse to reset the drive's fault *)
    Running       : BOOL;
    AtSpeed       : BOOL;
    Error         : BOOL;
    ErrorID       : UDINT;
    Status        : RB_DEVICE_STATUS;
END_VAR
VAR
    resetEdge : R_TRIG;
    want      : BOOL;
    speed     : REAL;
    rev       : BOOL;
    tMismatch : TON;
    tSpeed    : TON;
    deviation : BOOL;
END_VAR
resetEdge(CLK := Reset);
ResetDrive := resetEdge.Q;
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
IF DriveFault AND NOT Error THEN
    Error := TRUE;
    ErrorID := UDINT#3;
END_IF;
IF Mode = RB_MODE#Auto THEN
    want := AutoRun;
    speed := AutoSpeed;
    rev := AutoReverse;
ELSIF Mode = RB_MODE#Manual THEN
    want := ManRun;
    speed := ManSpeed;
    rev := ManReverse;
ELSE
    want := FALSE;
    speed := 0.0;
END_IF;
IF want AND NOT Run AND (NOT Permissive OR NOT DriveReady) THEN
    want := FALSE;
END_IF;
IF Interlock OR Error THEN
    want := FALSE;
END_IF;
IF want AND NOT Run THEN
    Status.Starts := Status.Starts + 1;
END_IF;
Run := want;
IF Run THEN
    SpeedSetpoint := LIMIT(SpeedMin, speed, SpeedMax);
    Reverse := rev;
ELSE
    SpeedSetpoint := 0.0;
    Reverse := FALSE;
END_IF;
tMismatch(IN := Run XOR DriveRunning, PT := FeedbackTime);
deviation := SpeedTolerance > 0.0 AND Run AND DriveRunning
             AND ABS(ActualSpeed - SpeedSetpoint) > SpeedTolerance;
tSpeed(IN := deviation, PT := FeedbackTime);
IF NOT Error THEN
    IF tMismatch.Q THEN
        Error := TRUE;
        IF Run THEN
            ErrorID := UDINT#1;
        ELSE
            ErrorID := UDINT#2;
        END_IF;
    ELSIF tSpeed.Q THEN
        Error := TRUE;
        ErrorID := UDINT#4;
    END_IF;
END_IF;
IF Error THEN
    Run := FALSE;
    SpeedSetpoint := 0.0;
    Reverse := FALSE;
END_IF;
Running := DriveRunning;
AtSpeed := Run AND DriveRunning AND NOT deviation;
Status.Mode := Mode;
Status.Commanded := Run;
Status.Active := Running;
Status.Error := Error;
Status.ErrorID := ErrorID;
END_FUNCTION_BLOCK

(* F03.CYCLETIME: the time since the previous call, in seconds, measured
   with a standard timer ([blocks.testable]). Seconds is 0 in the first call. *)
FUNCTION_BLOCK RB_CycleTime
VAR_OUTPUT
    Seconds   : LREAL;    (* seconds since the previous call *)
    Elapsed   : TIME;     (* the same, exact *)
    FirstCall : BOOL;
END_VAR
VAR
    clock   : TON;
    last    : TIME;
    started : BOOL;
END_VAR
VAR CONSTANT
    Period : TIME := T#1d;    (* the clock restarts once per period *)
END_VAR
clock(IN := TRUE, PT := Period);
FirstCall := NOT started;
IF started THEN
    Elapsed := clock.ET - last;
    Seconds := TIME_TO_LREAL(Elapsed) / 1000.0;
ELSE
    Elapsed := T#0s;
    Seconds := 0.0;
    started := TRUE;
END_IF;
last := clock.ET;
IF clock.Q THEN
    (* restart the clock once a day without losing time *)
    clock(IN := FALSE, PT := Period);
    clock(IN := TRUE, PT := Period);
    last := clock.ET;
END_IF;
END_FUNCTION_BLOCK

(* F01.FILTER.PT1: first-order low-pass filter with time constant T. *)
FUNCTION_BLOCK RB_FilterPT1
VAR_INPUT
    In    : REAL;
    T     : TIME := T#1s;     (* time constant; T#0s passes In through *)
    Track : BOOL;             (* TRUE: Out follows In directly *)
END_VAR
VAR_OUTPUT
    Out : REAL;
END_VAR
VAR
    cyc : RB_CycleTime;
    tc : LREAL;
END_VAR
cyc();
tc := TIME_TO_LREAL(T) / 1000.0;
IF cyc.FirstCall OR Track OR tc <= 0.0 THEN
    Out := In;
ELSE
    Out := LREAL_TO_REAL(REAL_TO_LREAL(Out) + (REAL_TO_LREAL(In) - REAL_TO_LREAL(Out)) * cyc.Seconds / (tc + cyc.Seconds));
END_IF;
END_FUNCTION_BLOCK

(* F01.AVERAGE: moving average over the last Window samples (one sample
   per call, at most 32). Valid when the window is full. *)
FUNCTION_BLOCK RB_MovingAverage
VAR_INPUT
    In     : REAL;
    Window : INT := 10;       (* 1 .. 32 samples *)
    Reset  : BOOL;            (* rising edge: empty the window *)
END_VAR
VAR_OUTPUT
    Out   : REAL;
    Valid : BOOL;
END_VAR
VAR
    resetEdge : R_TRIG;
    buf       : ARRAY[1..32] OF REAL;
    n         : INT;
    pos       : INT;
    used      : INT;
    sum       : LREAL;
    i         : INT;
END_VAR
resetEdge(CLK := Reset);
n := LIMIT(1, Window, 32);
IF resetEdge.Q THEN
    used := 0;
    pos := 0;
END_IF;
pos := pos MOD n + 1;
buf[pos] := In;
used := MIN(used + 1, n);
sum := 0.0;
FOR i := 1 TO used DO
    sum := sum + REAL_TO_LREAL(buf[i]);
END_FOR;
Out := LREAL_TO_REAL(sum / INT_TO_LREAL(used));
Valid := used >= n;
END_FUNCTION_BLOCK

(* F01.RAMP: rate limiter. Out follows In at most at RiseRate (up) and
   FallRate (down), in units per second; a rate of 0 means no limit. *)
FUNCTION_BLOCK RB_Ramp
VAR_INPUT
    In       : REAL;
    RiseRate : REAL := 0.0;
    FallRate : REAL := 0.0;
    Track    : BOOL;          (* TRUE: Out follows In directly *)
END_VAR
VAR_OUTPUT
    Out  : REAL;
    Busy : BOOL;              (* Out has not reached In yet *)
END_VAR
VAR
    cyc : RB_CycleTime;
    o   : LREAL;
    x   : LREAL;
    hi  : LREAL;
    lo  : LREAL;
END_VAR
cyc();
o := REAL_TO_LREAL(Out);
x := REAL_TO_LREAL(In);
IF cyc.FirstCall OR Track THEN
    o := x;
ELSE
    (* the output may move at most one rate step up or down this call *)
    hi := MAX(o, x);
    lo := MIN(o, x);
    IF RiseRate > 0.0 THEN
        hi := o + REAL_TO_LREAL(RiseRate) * cyc.Seconds;
    END_IF;
    IF FallRate > 0.0 THEN
        lo := o - REAL_TO_LREAL(FallRate) * cyc.Seconds;
    END_IF;
    o := LIMIT(lo, x, hi);
END_IF;
Out := LREAL_TO_REAL(o);
Busy := Out <> In;
END_FUNCTION_BLOCK

(* F01.DEADBAND: Out changes only when In has moved more than Deadband
   away from it (suppresses noise and chatter downstream). *)
FUNCTION_BLOCK RB_Deadband
VAR_INPUT
    In       : REAL;
    Deadband : REAL := 0.0;
END_VAR
VAR_OUTPUT
    Out : REAL;
END_VAR
VAR
    started : BOOL;
END_VAR
IF NOT started OR ABS(In - Out) > Deadband THEN
    Out := In;
    started := TRUE;
END_IF;
END_FUNCTION_BLOCK

(* F01.DEBOUNCE: a contact that must be stable before Out follows it:
   OnDelay before it switches on, OffDelay before it switches off. *)
FUNCTION_BLOCK RB_Debounce
VAR_INPUT
    In       : BOOL;
    OnDelay  : TIME := T#20ms;
    OffDelay : TIME := T#20ms;
END_VAR
VAR_OUTPUT
    Out : BOOL;
END_VAR
VAR
    tOn  : TON;
    tOff : TON;
END_VAR
tOn(IN := In AND NOT Out, PT := OnDelay);
tOff(IN := Out AND NOT In, PT := OffDelay);
IF tOn.Q THEN
    Out := TRUE;
ELSIF tOff.Q THEN
    Out := FALSE;
END_IF;
END_FUNCTION_BLOCK

(* F06.PID: PID controller with anti-windup (the integral is kept within
   the output range), derivative on the measurement, bumpless manual/auto
   switching, reverse (heating) or direct (cooling) action.
   ErrorID 1 invalid output range (OutMin >= OutMax). Safe state: Out =
   OutMin. *)
FUNCTION_BLOCK RB_PID
VAR_INPUT
    Mode     : RB_MODE := RB_MODE#Off;
    SP       : REAL;               (* set point *)
    PV       : REAL;               (* process value *)
    Kp       : REAL := 1.0;        (* proportional gain *)
    Ti       : TIME := T#0s;       (* integral time; T#0s: no integral *)
    Td       : TIME := T#0s;       (* derivative time; T#0s: no derivative *)
    OutMin   : REAL := 0.0;
    OutMax   : REAL := 100.0;
    ManValue : REAL;               (* output in Manual *)
    Direct   : BOOL;               (* FALSE: error = SP - PV; TRUE: PV - SP *)
    Reset    : BOOL;
END_VAR
VAR_OUTPUT
    Out       : REAL;
    Saturated : BOOL;              (* Auto and Out at OutMin or OutMax *)
    Error     : BOOL;
    ErrorID   : UDINT;
END_VAR
VAR
    resetEdge : R_TRIG;
    cyc       : RB_CycleTime;
    e         : LREAL;
    p         : LREAL;
    i         : LREAL;
    d         : LREAL;
    u         : LREAL;
    lo        : LREAL;
    hi        : LREAL;
    lastPV    : LREAL;
    intSec    : LREAL;
    derSec    : LREAL;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
cyc();
IF OutMin >= OutMax AND NOT Error THEN
    Error := TRUE;
    ErrorID := UDINT#1;
END_IF;
lo := REAL_TO_LREAL(OutMin);
hi := REAL_TO_LREAL(OutMax);
IF Direct THEN
    e := REAL_TO_LREAL(PV) - REAL_TO_LREAL(SP);
ELSE
    e := REAL_TO_LREAL(SP) - REAL_TO_LREAL(PV);
END_IF;
p := REAL_TO_LREAL(Kp) * e;
intSec := TIME_TO_LREAL(Ti) / 1000.0;
derSec := TIME_TO_LREAL(Td) / 1000.0;
d := 0.0;
IF cyc.Seconds > 0.0 THEN
    (* on the measurement, so a set-point step gives no kick *)
    d := REAL_TO_LREAL(Kp) * derSec * (REAL_TO_LREAL(PV) - lastPV) / cyc.Seconds;
    IF NOT Direct THEN
        d := -d;
    END_IF;
END_IF;
lastPV := REAL_TO_LREAL(PV);
IF Error THEN
    u := lo;
    i := 0.0;
ELSIF Mode = RB_MODE#Auto THEN
    IF intSec > 0.0 THEN
        i := i + REAL_TO_LREAL(Kp) * e * cyc.Seconds / intSec;
    ELSE
        i := 0.0;
    END_IF;
    (* anti-windup: the integral never pushes beyond the output range *)
    i := LIMIT(lo - p - d, i, hi - p - d);
    u := LIMIT(lo, p + i + d, hi);
ELSE
    IF Mode = RB_MODE#Manual THEN
        u := LIMIT(lo, REAL_TO_LREAL(ManValue), hi);
    ELSE
        u := lo;
    END_IF;
    (* bumpless: the integral tracks, so Auto starts from this output *)
    i := u - p;
END_IF;
Out := LREAL_TO_REAL(u);
Saturated := Mode = RB_MODE#Auto AND NOT Error AND (u <= lo OR u >= hi);
END_FUNCTION_BLOCK

(* F06.ONOFF: on/off control with hysteresis (thermostat). Heating
   (Direct FALSE): on at or below SP - Hysteresis/2, off at or above
   SP + Hysteresis/2; cooling (Direct TRUE) the other way round. *)
FUNCTION_BLOCK RB_OnOff
VAR_INPUT
    Enable     : BOOL;
    SP         : REAL;
    PV         : REAL;
    Hysteresis : REAL := 1.0;      (* total band around SP *)
    Direct     : BOOL;             (* TRUE: cooling *)
END_VAR
VAR_OUTPUT
    Out : BOOL;
END_VAR
VAR
    half : REAL;
END_VAR
half := ABS(Hysteresis) / 2.0;
IF NOT Enable THEN
    Out := FALSE;
ELSIF Direct THEN
    IF PV >= SP + half THEN
        Out := TRUE;
    ELSIF PV <= SP - half THEN
        Out := FALSE;
    END_IF;
ELSE
    IF PV <= SP - half THEN
        Out := TRUE;
    ELSIF PV >= SP + half THEN
        Out := FALSE;
    END_IF;
END_IF;
END_FUNCTION_BLOCK

(* F08.ALARM: an alarm with on/off delays and acknowledgement, with the
   ISA-18.2 states. Enable FALSE takes it out of service (shelved). *)
FUNCTION_BLOCK RB_Alarm
VAR_INPUT
    In       : BOOL;               (* alarm condition *)
    Enable   : BOOL := TRUE;       (* FALSE: out of service, state Normal *)
    OnDelay  : TIME := T#0s;
    OffDelay : TIME := T#0s;
    Ack      : BOOL;               (* rising edge acknowledges *)
END_VAR
VAR_OUTPUT
    Active  : BOOL;                (* condition present, after the delays *)
    Unacked : BOOL;                (* needs acknowledging *)
    State   : RB_ALARM_STATE;
    Count   : UDINT;               (* times the alarm became active *)
END_VAR
VAR
    tOn     : TON;
    tOff    : TON;
    ackEdge : R_TRIG;
END_VAR
ackEdge(CLK := Ack);
tOn(IN := Enable AND In AND NOT Active, PT := OnDelay);
tOff(IN := Active AND NOT In, PT := OffDelay);
IF NOT Enable THEN
    Active := FALSE;
    Unacked := FALSE;
ELSIF tOn.Q THEN
    Active := TRUE;
    Unacked := TRUE;
    Count := Count + 1;
ELSIF tOff.Q THEN
    Active := FALSE;
END_IF;
IF ackEdge.Q THEN
    Unacked := FALSE;
END_IF;
IF Active AND Unacked THEN
    State := RB_ALARM_STATE#ActiveUnack;
ELSIF Active THEN
    State := RB_ALARM_STATE#ActiveAcked;
ELSIF Unacked THEN
    State := RB_ALARM_STATE#ReturnedUnack;
ELSE
    State := RB_ALARM_STATE#Normal;
END_IF;
END_FUNCTION_BLOCK

(* F05.STEPS: a step chain. The application programs the actions of each
   step in a CASE on StepNo and sets Proceed to the condition that ends the
   current step (and NextStep to branch). StepNo 0 is idle.
   ErrorID 1 step timeout. *)
FUNCTION_BLOCK RB_StepChain
VAR_INPUT
    Start       : BOOL;               (* rising edge: idle -> step 1 *)
    Proceed     : BOOL;               (* the current step is finished *)
    NextStep    : INT;                (* 0: StepNo + 1; otherwise the step to go to *)
    LastStep    : INT := 1;           (* after this step the chain is done *)
    StepTimeout : TIME := T#0s;       (* for the current step; T#0s: none *)
    Hold        : BOOL;               (* TRUE: stay, transitions ignored, timer paused *)
    Abort       : BOOL;               (* TRUE: back to idle *)
    Reset       : BOOL;               (* rising edge clears a timeout *)
END_VAR
VAR_OUTPUT
    StepNo    : INT;                  (* 0 idle, 1 .. LastStep *)
    StepTime  : TIME;                 (* time in the current step, without holds *)
    FirstCall : BOOL;                 (* TRUE in the first call of a step *)
    Busy      : BOOL;
    Done      : BOOL;                 (* TRUE for one call when the chain ends *)
    Aborted   : BOOL;                 (* TRUE for one call after an abort *)
    Held      : BOOL;
    Error     : BOOL;
    ErrorID   : UDINT;
END_VAR
VAR
    startEdge : R_TRIG;
    resetEdge : R_TRIG;
    cyc       : RB_CycleTime;
    elapsed   : LREAL;
END_VAR
startEdge(CLK := Start);
resetEdge(CLK := Reset);
cyc();
Done := FALSE;
Aborted := FALSE;
FirstCall := FALSE;
IF resetEdge.Q AND Error THEN
    Error := FALSE;
    ErrorID := 0;
    elapsed := 0.0;
END_IF;
IF Abort THEN
    IF StepNo <> 0 THEN
        Aborted := TRUE;
    END_IF;
    StepNo := 0;
    Error := FALSE;
    ErrorID := 0;
    elapsed := 0.0;
ELSIF StepNo = 0 THEN
    IF startEdge.Q THEN
        StepNo := 1;
        elapsed := 0.0;
        FirstCall := TRUE;
    END_IF;
ELSIF NOT Hold AND NOT Error THEN
    elapsed := elapsed + cyc.Seconds;
    IF Proceed THEN
        IF StepNo >= LastStep AND NextStep = 0 THEN
            StepNo := 0;
            Done := TRUE;
        ELSE
            IF NextStep = 0 THEN
                StepNo := StepNo + 1;
            ELSE
                StepNo := NextStep;
            END_IF;
            FirstCall := TRUE;
        END_IF;
        elapsed := 0.0;
    ELSIF StepTimeout > T#0s AND elapsed >= TIME_TO_LREAL(StepTimeout) / 1000.0 THEN
        Error := TRUE;
        ErrorID := UDINT#1;
    END_IF;
END_IF;
StepTime := LREAL_TO_TIME(elapsed * 1000.0);
Busy := StepNo <> 0;
Held := Busy AND Hold;
END_FUNCTION_BLOCK

(* F05.PHASE: the state model of a batch phase (ISA-88 state names).
   Commands act on their rising edge; Finished (from the phase logic) ends
   Running. A command that is not valid in the current state is ignored and
   reported in Rejected for that call. *)
FUNCTION_BLOCK RB_Phase
VAR_INPUT
    Start    : BOOL;
    Hold     : BOOL;
    Restart  : BOOL;
    Stop     : BOOL;
    Abort    : BOOL;
    Reset    : BOOL;
    Finished : BOOL;                  (* the phase logic has completed *)
END_VAR
VAR_OUTPUT
    State    : RB_PHASE_STATE;
    Running  : BOOL;
    Done     : BOOL;                  (* State = Complete *)
    Rejected : BOOL;                  (* a command was not valid in this state *)
END_VAR
VAR
    eStart   : R_TRIG;
    eHold    : R_TRIG;
    eRestart : R_TRIG;
    eStop    : R_TRIG;
    eAbort   : R_TRIG;
    eReset   : R_TRIG;
END_VAR
eStart(CLK := Start);
eHold(CLK := Hold);
eRestart(CLK := Restart);
eStop(CLK := Stop);
eAbort(CLK := Abort);
eReset(CLK := Reset);
Rejected := FALSE;
IF eAbort.Q THEN
    IF State = RB_PHASE_STATE#Running OR State = RB_PHASE_STATE#Held OR State = RB_PHASE_STATE#Stopped THEN
        State := RB_PHASE_STATE#Aborted;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eStop.Q THEN
    IF State = RB_PHASE_STATE#Running OR State = RB_PHASE_STATE#Held THEN
        State := RB_PHASE_STATE#Stopped;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eHold.Q THEN
    IF State = RB_PHASE_STATE#Running THEN
        State := RB_PHASE_STATE#Held;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eRestart.Q THEN
    IF State = RB_PHASE_STATE#Held THEN
        State := RB_PHASE_STATE#Running;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eStart.Q THEN
    IF State = RB_PHASE_STATE#Idle THEN
        State := RB_PHASE_STATE#Running;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eReset.Q THEN
    IF State = RB_PHASE_STATE#Complete OR State = RB_PHASE_STATE#Stopped OR State = RB_PHASE_STATE#Aborted THEN
        State := RB_PHASE_STATE#Idle;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF Finished AND State = RB_PHASE_STATE#Running THEN
    State := RB_PHASE_STATE#Complete;
END_IF;
Running := State = RB_PHASE_STATE#Running;
Done := State = RB_PHASE_STATE#Complete;
END_FUNCTION_BLOCK

(* F10.MODES: the operating mode of a machine or unit, fed to the Mode
   input of its device modules. The emergency-stop status from the safety
   system forces Off (the safety function itself stays on certified
   hardware). *)
FUNCTION_BLOCK RB_ModeManager
VAR_INPUT
    ReqOff        : BOOL;             (* rising edge: request Off *)
    ReqManual     : BOOL;             (* rising edge: request Manual *)
    ReqAuto       : BOOL;             (* rising edge: request Auto *)
    AutoAllowed   : BOOL := TRUE;     (* e.g. homed, no fault, guards closed *)
    ManualAllowed : BOOL := TRUE;
    EStopOk       : BOOL := TRUE;     (* status from the safety system *)
    Fault         : BOOL;             (* a machine fault: Auto drops to Off *)
END_VAR
VAR_OUTPUT
    Mode        : RB_MODE;
    ModeChanged : BOOL;               (* TRUE for one call after a change *)
    Rejected    : BOOL;               (* a request was not allowed *)
END_VAR
VAR
    eOff    : R_TRIG;
    eManual : R_TRIG;
    eAuto   : R_TRIG;
    before  : RB_MODE;
END_VAR
eOff(CLK := ReqOff);
eManual(CLK := ReqManual);
eAuto(CLK := ReqAuto);
before := Mode;
Rejected := FALSE;
IF NOT EStopOk THEN
    Mode := RB_MODE#Off;
    Rejected := eManual.Q OR eAuto.Q;
ELSIF eOff.Q THEN
    Mode := RB_MODE#Off;
ELSIF eManual.Q THEN
    IF ManualAllowed THEN
        Mode := RB_MODE#Manual;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eAuto.Q THEN
    IF AutoAllowed AND NOT Fault THEN
        Mode := RB_MODE#Auto;
    ELSE
        Rejected := TRUE;
    END_IF;
END_IF;
IF Mode = RB_MODE#Auto AND (Fault OR NOT AutoAllowed) THEN
    Mode := RB_MODE#Off;
END_IF;
IF Mode = RB_MODE#Manual AND NOT ManualAllowed THEN
    Mode := RB_MODE#Off;
END_IF;
ModeChanged := Mode <> before;
END_FUNCTION_BLOCK

(* F10.STATE: the state of a machine, a subset of the PackML state model.
   Commands act on their rising edge; the acting states (Resetting,
   Starting, Stopping) end when the machine logic reports done. A command
   not valid in the state is ignored and reported in Rejected. *)
FUNCTION_BLOCK RB_MachineState
VAR_INPUT
    Reset     : BOOL;
    Start     : BOOL;
    Stop      : BOOL;
    Hold      : BOOL;
    Unhold    : BOOL;
    Abort     : BOOL;
    Clear     : BOOL;
    ResetDone : BOOL;                 (* machine logic: resetting finished *)
    StartDone : BOOL;                 (* machine logic: starting finished *)
    StopDone  : BOOL;                 (* machine logic: stopping finished *)
END_VAR
VAR_OUTPUT
    State    : RB_MACHINE_STATE;
    Producing : BOOL;                 (* State = Execute *)
    Rejected : BOOL;
END_VAR
VAR
    eReset  : R_TRIG;
    eStart  : R_TRIG;
    eStop   : R_TRIG;
    eHold   : R_TRIG;
    eUnhold : R_TRIG;
    eAbort  : R_TRIG;
    eClear  : R_TRIG;
END_VAR
eReset(CLK := Reset);
eStart(CLK := Start);
eStop(CLK := Stop);
eHold(CLK := Hold);
eUnhold(CLK := Unhold);
eAbort(CLK := Abort);
eClear(CLK := Clear);
Rejected := FALSE;
IF eAbort.Q THEN
    IF State <> RB_MACHINE_STATE#Aborted THEN
        State := RB_MACHINE_STATE#Aborted;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eClear.Q THEN
    IF State = RB_MACHINE_STATE#Aborted THEN
        State := RB_MACHINE_STATE#Stopped;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eStop.Q THEN
    IF State = RB_MACHINE_STATE#Idle OR State = RB_MACHINE_STATE#Starting
       OR State = RB_MACHINE_STATE#Execute OR State = RB_MACHINE_STATE#Held THEN
        State := RB_MACHINE_STATE#Stopping;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eHold.Q THEN
    IF State = RB_MACHINE_STATE#Execute THEN
        State := RB_MACHINE_STATE#Held;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eUnhold.Q THEN
    IF State = RB_MACHINE_STATE#Held THEN
        State := RB_MACHINE_STATE#Execute;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eStart.Q THEN
    IF State = RB_MACHINE_STATE#Idle THEN
        State := RB_MACHINE_STATE#Starting;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF eReset.Q THEN
    IF State = RB_MACHINE_STATE#Stopped THEN
        State := RB_MACHINE_STATE#Resetting;
    ELSE
        Rejected := TRUE;
    END_IF;
ELSIF State = RB_MACHINE_STATE#Resetting AND ResetDone THEN
    State := RB_MACHINE_STATE#Idle;
ELSIF State = RB_MACHINE_STATE#Starting AND StartDone THEN
    State := RB_MACHINE_STATE#Execute;
ELSIF State = RB_MACHINE_STATE#Stopping AND StopDone THEN
    State := RB_MACHINE_STATE#Stopped;
END_IF;
Producing := State = RB_MACHINE_STATE#Execute;
END_FUNCTION_BLOCK

(* F03.COUNTER: counts rising edges of In up to Preset, with a lifetime
   total and batch counting. *)
FUNCTION_BLOCK RB_Counter
VAR_INPUT
    In          : BOOL;               (* counts on the rising edge *)
    Preset      : UDINT := 10;
    AutoRestart : BOOL;               (* TRUE: start the next batch at once *)
    Reset       : BOOL;               (* rising edge: count back to 0 *)
END_VAR
VAR_OUTPUT
    Count     : UDINT;
    Done      : BOOL;                 (* Count reached Preset *)
    Remaining : UDINT;
    BatchDone : BOOL;                 (* TRUE for one call when a batch completes *)
    Batches   : UDINT;
    Total     : UDINT;                (* every count, never reset *)
END_VAR
VAR
    eIn    : R_TRIG;
    eReset : R_TRIG;
END_VAR
eIn(CLK := In);
eReset(CLK := Reset);
BatchDone := FALSE;
IF eReset.Q THEN
    Count := 0;
END_IF;
IF eIn.Q THEN
    Total := Total + 1;
    IF Count >= Preset AND AutoRestart THEN
        Count := 0;
    END_IF;
    IF Count < Preset THEN
        Count := Count + 1;
        IF Count >= Preset THEN
            BatchDone := TRUE;
            Batches := Batches + 1;
        END_IF;
    END_IF;
END_IF;
Done := Count >= Preset;
Remaining := Preset - MIN(Count, Preset);
END_FUNCTION_BLOCK

(* F12.ZONE: a zone of a zero-pressure accumulation conveyor with one photo
   eye at its end. A part moves on while the next zone is free and waits at
   the end otherwise. The zone is occupied from the moment the previous zone
   has handed a part over (or the eye sees one) until the part has left. ErrorID 1 jam (a part being handed on does not leave
   the photo eye within JamTime). Safe state: zone motor off. *)
FUNCTION_BLOCK RB_ConveyorZone
VAR_INPUT
    Enable          : BOOL;            (* the line runs *)
    PartAtEnd       : BOOL;            (* photo eye at the zone end *)
    DownstreamFree  : BOOL;            (* the next zone can take a part *)
    UpstreamFeeding : BOOL;            (* the previous zone hands a part on *)
    SleepTime       : TIME := T#0s;    (* empty and not fed this long: stop; T#0s: never *)
    JamTime         : TIME := T#5s;    (* T#0s: no jam supervision *)
    Reset           : BOOL;
END_VAR
VAR_OUTPUT
    Run      : BOOL;                   (* zone motor *)
    Occupied : BOOL;
    Free     : BOOL;                   (* this zone can take a part *)
    Feeding  : BOOL;                   (* handing a part to the next zone *)
    Count    : UDINT;                  (* parts handed on *)
    Error    : BOOL;
    ErrorID  : UDINT;
END_VAR
VAR
    resetEdge : R_TRIG;
    leaving   : F_TRIG;
    received  : F_TRIG;
    tIdle     : TON;
    tJam      : TON;
    awake     : BOOL;
    holding   : BOOL;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
tIdle(IN := NOT UpstreamFeeding AND NOT PartAtEnd, PT := SleepTime);
awake := SleepTime = T#0s OR NOT tIdle.Q;
Feeding := Enable AND NOT Error AND PartAtEnd AND DownstreamFree;
tJam(IN := Feeding AND JamTime > T#0s, PT := JamTime);
IF tJam.Q AND NOT Error THEN
    Error := TRUE;
    ErrorID := UDINT#1;
    Feeding := FALSE;
END_IF;
(* occupancy: a part handed over by the previous zone, or seen at the end *)
leaving(CLK := PartAtEnd);
received(CLK := UpstreamFeeding);
IF leaving.Q THEN
    holding := FALSE;
    IF Run THEN
        Count := Count + 1;
    END_IF;
END_IF;
IF received.Q OR PartAtEnd THEN
    holding := TRUE;
END_IF;
Run := Enable AND NOT Error AND (Feeding OR (NOT PartAtEnd AND awake));
Occupied := holding;
Free := Enable AND NOT Error AND NOT holding;
END_FUNCTION_BLOCK

(* F09.RUNHOURS: run hours, starts and a maintenance interval. The
   application keeps the values over a restart with Preset / Load (for
   example from RETAIN variables). *)
FUNCTION_BLOCK RB_RunHours
VAR_INPUT
    Running      : BOOL;
    Interval     : LREAL := 0.0;       (* hours between services; 0: none *)
    ServiceDone  : BOOL;               (* rising edge: a service was done *)
    Load         : BOOL;               (* rising edge: take the preset values *)
    PresetHours  : LREAL;
    PresetStarts : UDINT;
    PresetSince  : LREAL;              (* hours since the last service *)
END_VAR
VAR_OUTPUT
    Hours          : LREAL;
    Starts         : UDINT;
    SinceService   : LREAL;
    MaintenanceDue : BOOL;
END_VAR
VAR
    cyc       : RB_CycleTime;
    eRun      : R_TRIG;
    eService  : R_TRIG;
    eLoad     : R_TRIG;
    wasRunning : BOOL;
END_VAR
cyc();
eRun(CLK := Running);
eService(CLK := ServiceDone);
eLoad(CLK := Load);
IF eLoad.Q THEN
    Hours := PresetHours;
    Starts := PresetStarts;
    SinceService := PresetSince;
END_IF;
(* the time since the previous call counts when the device was running then *)
IF wasRunning THEN
    Hours := Hours + cyc.Seconds / 3600.0;
    SinceService := SinceService + cyc.Seconds / 3600.0;
END_IF;
IF eRun.Q THEN
    Starts := Starts + 1;
END_IF;
IF eService.Q THEN
    SinceService := 0.0;
END_IF;
wasRunning := Running;
MaintenanceDue := Interval > 0.0 AND SinceService >= Interval;
END_FUNCTION_BLOCK

(* F09.HEARTBEAT: a toggling heartbeat to a partner (SCADA, another PLC)
   and supervision of the partner's heartbeat. *)
FUNCTION_BLOCK RB_Heartbeat
VAR_INPUT
    PartnerBeat : BOOL;                (* the partner's toggling signal *)
    Period      : TIME := T#1s;        (* own heartbeat half-period *)
    Timeout     : TIME := T#5s;        (* no change this long: link lost *)
END_VAR
VAR_OUTPUT
    Beat      : BOOL;                  (* own toggling signal *)
    Alive     : BOOL;                  (* the partner's beat changed within Timeout *)
    LostCount : UDINT;
END_VAR
VAR
    tBeat   : TON;
    tSilent : TON;
    last     : BOOL;
    wasAlive : BOOL;
END_VAR
tBeat(IN := TRUE, PT := Period);
IF tBeat.Q THEN
    Beat := NOT Beat;
    tBeat(IN := FALSE, PT := Period);
    tBeat(IN := TRUE, PT := Period);
END_IF;
(* a change resets the silence timer, which then times from this call *)
tSilent(IN := PartnerBeat = last, PT := Timeout);
last := PartnerBeat;
tSilent(IN := TRUE, PT := Timeout);
Alive := NOT tSilent.Q;
IF wasAlive AND NOT Alive THEN
    LostCount := LostCount + 1;
END_IF;
wasAlive := Alive;
END_FUNCTION_BLOCK

(* F11.FIFO: a first-in first-out queue of up to 32 DINT values (part IDs,
   codes). ErrorID 1 put on a full queue (value dropped), 2 get on an empty
   queue. *)
FUNCTION_BLOCK RB_Fifo
VAR_INPUT
    Put     : BOOL;                  (* rising edge: append InValue *)
    InValue : DINT;
    Get     : BOOL;                  (* rising edge: take the oldest into OutValue *)
    Clear   : BOOL;                  (* rising edge: empty the queue *)
    Reset   : BOOL;                  (* rising edge: clear an error *)
END_VAR
VAR_OUTPUT
    OutValue : DINT;
    First    : DINT;                 (* the oldest value, without taking it *)
    Count    : INT;
    Empty    : BOOL;
    Full     : BOOL;
    Error    : BOOL;
    ErrorID  : UDINT;
END_VAR
VAR
    ePut   : R_TRIG;
    eGet   : R_TRIG;
    eClear : R_TRIG;
    eReset : R_TRIG;
    buf    : ARRAY[0..31] OF DINT;
    head   : INT;                    (* index of the oldest value *)
END_VAR
ePut(CLK := Put);
eGet(CLK := Get);
eClear(CLK := Clear);
eReset(CLK := Reset);
IF eReset.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
IF eClear.Q THEN
    Count := 0;
END_IF;
IF eGet.Q THEN
    IF Count > 0 THEN
        OutValue := buf[head];
        head := (head + 1) MOD 32;
        Count := Count - 1;
    ELSE
        Error := TRUE;
        ErrorID := UDINT#2;
    END_IF;
END_IF;
IF ePut.Q THEN
    IF Count < 32 THEN
        buf[(head + Count) MOD 32] := InValue;
        Count := Count + 1;
    ELSE
        Error := TRUE;
        ErrorID := UDINT#1;
    END_IF;
END_IF;
Empty := Count = 0;
Full := Count >= 32;
IF Empty THEN
    First := 0;
ELSE
    First := buf[head];
END_IF;
END_FUNCTION_BLOCK

(* F11.RECIPE: loads a recipe (8 parameters) from a table of 16 kept by the
   application, and saves the current parameters into it. ErrorID 1 recipe
   number out of range. *)
FUNCTION_BLOCK RB_RecipeTable
VAR_INPUT
    Number : INT := 1;               (* 1 .. 16 *)
    Load   : BOOL;                   (* rising edge: Params := table[Number] *)
    Save   : BOOL;                   (* rising edge: table[Number] := Actual *)
    Actual : ARRAY[1..8] OF REAL;    (* the parameters in use, to save *)
    Reset  : BOOL;
END_VAR
VAR_IN_OUT
    Table : ARRAY[1..16, 1..8] OF REAL;
END_VAR
VAR_OUTPUT
    Params  : ARRAY[1..8] OF REAL;
    Loaded  : INT;                   (* the recipe last loaded; 0: none *)
    Done    : BOOL;                  (* TRUE for one call after a load or save *)
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    eLoad  : R_TRIG;
    eSave  : R_TRIG;
    eReset : R_TRIG;
    k      : INT;
END_VAR
eLoad(CLK := Load);
eSave(CLK := Save);
eReset(CLK := Reset);
Done := FALSE;
IF eReset.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
IF eLoad.Q OR eSave.Q THEN
    IF Number < 1 OR Number > 16 THEN
        Error := TRUE;
        ErrorID := UDINT#1;
    ELSE
        FOR k := 1 TO 8 DO
            IF eSave.Q THEN
                Table[Number, k] := Actual[k];
            END_IF;
            IF eLoad.Q THEN
                Params[k] := Table[Number, k];
            END_IF;
        END_FOR;
        IF eLoad.Q THEN
            Loaded := Number;
        END_IF;
        Done := TRUE;
    END_IF;
END_IF;
END_FUNCTION_BLOCK

(* F11.TRANSFER: hands a part to the next station with a handshake: when
   this station has a part and the receiver is ready, Release moves it
   until the receiver confirms arrival. ErrorID 1 the receiver did not
   confirm within Timeout. *)
FUNCTION_BLOCK RB_Transfer
VAR_INPUT
    PartReady     : BOOL;            (* this station has a part to hand on *)
    ReceiverReady : BOOL;            (* the next station can take it *)
    Arrived       : BOOL;            (* the next station has the part *)
    Timeout       : TIME := T#10s;
    Reset         : BOOL;
END_VAR
VAR_OUTPUT
    Release : BOOL;                  (* move the part (conveyor, gripper, gate) *)
    Busy    : BOOL;
    Done    : BOOL;                  (* TRUE for one call when a part arrived *)
    Count   : UDINT;
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    eReset : R_TRIG;
    tMove  : TON;
END_VAR
eReset(CLK := Reset);
Done := FALSE;
IF eReset.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
IF NOT Busy AND NOT Error AND PartReady AND ReceiverReady THEN
    Busy := TRUE;
END_IF;
tMove(IN := Busy, PT := Timeout);
IF Busy AND Arrived THEN
    Busy := FALSE;
    Done := TRUE;
    Count := Count + 1;
ELSIF Busy AND tMove.Q THEN
    Busy := FALSE;
    Error := TRUE;
    ErrorID := UDINT#1;
END_IF;
Release := Busy;
END_FUNCTION_BLOCK

(* F02.STARTSTOP: a start/stop latch; stop wins. Wire the stop button
   normally closed: StopOk FALSE (pressed or broken wire) stops. *)
FUNCTION_BLOCK RB_StartStop
VAR_INPUT
    Start      : BOOL;               (* rising edge starts *)
    StopOk     : BOOL := TRUE;       (* FALSE: stop *)
    Permissive : BOOL := TRUE;       (* needed to start *)
    Interlock  : BOOL;               (* TRUE: stop *)
END_VAR
VAR_OUTPUT
    Out : BOOL;
END_VAR
VAR
    eStart : R_TRIG;
END_VAR
eStart(CLK := Start);
IF NOT StopOk OR Interlock THEN
    Out := FALSE;
ELSIF eStart.Q AND Permissive THEN
    Out := TRUE;
END_IF;
END_FUNCTION_BLOCK

(* F02.PERMISSIVES: up to 16 start conditions. Ok when every used one is
   TRUE; FirstOut is the first condition that dropped (first-out), kept
   until Reset when all are TRUE again. *)
FUNCTION_BLOCK RB_Permissives
VAR_INPUT
    Cond  : ARRAY[1..16] OF BOOL;
    Used  : WORD := WORD#16#FFFF;    (* bit k-1 set: condition k is used *)
    Reset : BOOL;                    (* rising edge: clear FirstOut *)
END_VAR
VAR_OUTPUT
    Ok       : BOOL;
    Missing  : INT;                  (* used conditions that are FALSE *)
    FirstOut : INT;                  (* 0: none *)
END_VAR
VAR
    eReset : R_TRIG;
    k      : INT;
    bad    : BOOL;
END_VAR
eReset(CLK := Reset);
Missing := 0;
FOR k := 1 TO 16 DO
    bad := ((SHR(Used, k - 1) AND WORD#1) <> WORD#0) AND NOT Cond[k];
    IF bad THEN
        Missing := Missing + 1;
        IF FirstOut = 0 THEN
            FirstOut := k;
        END_IF;
    END_IF;
END_FOR;
Ok := Missing = 0;
IF eReset.Q AND Ok THEN
    FirstOut := 0;
END_IF;
END_FUNCTION_BLOCK

(* F04.VALVE.ANALOG: a control valve with a position command (0 .. 100 %)
   and optional position feedback. ErrorID 1 position deviates from the
   command by more than Tolerance for FeedbackTime, 2 feedback signal out of
   range. Safe state: SafePos (default 0 %: closed; set 100 % for a valve
   that must open on a fault). *)
FUNCTION_BLOCK RB_ValveAnalog
VAR_INPUT
    Mode         : RB_MODE := RB_MODE#Off;
    AutoPos      : REAL;              (* % *)
    ManPos       : REAL;              (* % *)
    Interlock    : BOOL;              (* TRUE: go to SafePos now, in every mode *)
    SafePos      : REAL;              (* %: position in Off, on interlock and fault *)
    PosFb        : REAL;              (* % from the positioner *)
    Feedback     : BOOL := TRUE;      (* FALSE: no position feedback wired *)
    Tolerance    : REAL := 5.0;       (* % *)
    FeedbackTime : TIME := T#10s;
    Reset        : BOOL;              (* rising edge clears a fault *)
END_VAR
VAR_OUTPUT
    Out     : REAL;                   (* position command, 0 .. 100 % *)
    Pos     : REAL;                   (* position, from the feedback *)
    Error   : BOOL;
    ErrorID : UDINT;
    Status  : RB_DEVICE_STATUS;
END_VAR
VAR
    resetEdge : R_TRIG;
    want      : REAL;
    tDev      : TON;
    opened    : BOOL;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
IF Feedback AND (PosFb < -10.0 OR PosFb > 110.0) AND NOT Error THEN
    Error := TRUE;
    ErrorID := UDINT#2;
END_IF;
CASE Mode OF
RB_MODE#Auto:
    want := AutoPos;
RB_MODE#Manual:
    want := ManPos;
ELSE
    want := SafePos;
END_CASE;
IF Interlock OR Error THEN
    want := SafePos;
END_IF;
Out := LIMIT(0.0, want, 100.0);
IF Feedback THEN
    tDev(IN := ABS(Out - PosFb) > Tolerance, PT := FeedbackTime);
    IF tDev.Q AND NOT Error THEN
        Error := TRUE;
        ErrorID := UDINT#1;
        Out := LIMIT(0.0, SafePos, 100.0);
    END_IF;
    Pos := PosFb;
ELSE
    tDev(IN := FALSE, PT := FeedbackTime);
    Pos := Out;
END_IF;
(* a start is an opening from closed *)
IF Out > 0.0 AND NOT opened THEN
    Status.Starts := Status.Starts + 1;
END_IF;
opened := Out > 0.0;
Status.Mode := Mode;
Status.Commanded := opened;
Status.Active := Pos > Tolerance;
Status.Error := Error;
Status.ErrorID := ErrorID;
END_FUNCTION_BLOCK

(* F04.MOTOR.STARDELTA: a motor started star-delta with three contactors
   (main, star, delta), built on RB_Motor for the main contactor. Star and
   delta are never on together; between them both are off for Changeover.
   Faults as RB_Motor. Safe state: all contactors de-energised. *)
FUNCTION_BLOCK RB_MotorStarDelta
VAR_INPUT
    Mode         : RB_MODE := RB_MODE#Off;
    AutoRun      : BOOL;
    ManRun       : BOOL;
    Interlock    : BOOL;              (* TRUE: stop now, in every mode *)
    Permissive   : BOOL := TRUE;      (* FALSE: do not start *)
    FbRunning    : BOOL;              (* main contactor auxiliary contact *)
    Overload     : BOOL;
    Feedback     : BOOL := TRUE;
    FeedbackTime : TIME := T#2s;
    RestartDelay : TIME := T#0s;
    StarTime     : TIME := T#5s;      (* time in star *)
    Changeover   : TIME := T#50ms;    (* star off -> delta on *)
    Reset        : BOOL;
END_VAR
VAR_OUTPUT
    Main    : BOOL;                   (* main contactor *)
    Star    : BOOL;                   (* star contactor *)
    Delta   : BOOL;                   (* delta contactor *)
    Running : BOOL;
    InDelta : BOOL;                   (* started: running in delta *)
    Error   : BOOL;
    ErrorID : UDINT;
    Status  : RB_DEVICE_STATUS;
END_VAR
VAR
    motor : RB_Motor;
    tStar : TON;
    tGap  : TON;
END_VAR
motor(Mode := Mode, AutoRun := AutoRun, ManRun := ManRun, Interlock := Interlock,
      Permissive := Permissive, FbRunning := FbRunning, Overload := Overload,
      Feedback := Feedback, FeedbackTime := FeedbackTime, RestartDelay := RestartDelay,
      Reset := Reset);
Main := motor.Run;
tStar(IN := Main, PT := StarTime);
tGap(IN := tStar.Q, PT := Changeover);
Star := Main AND NOT tStar.Q;
Delta := Main AND tGap.Q;
Running := motor.Running;
InDelta := Delta;
Error := motor.Error;
ErrorID := motor.ErrorID;
Status := motor.Status;
END_FUNCTION_BLOCK

(* F06.SPLIT: split range. One controller output In (0 .. 100 %) drives
   two actuators: A over 0 .. SplitPoint, B over SplitPoint .. 100, with an
   optional dead band between them. InvertA: A runs 100 -> 0 as In rises
   (heating and cooling). ErrorID 1 SplitPoint and Deadband leave no range
   for A or B; the outputs are 0 (safe state). *)
FUNCTION_BLOCK RB_SplitRange
VAR_INPUT
    In         : REAL;                (* % *)
    SplitPoint : REAL := 50.0;        (* % *)
    Deadband   : REAL;                (* %, centred on SplitPoint *)
    InvertA    : BOOL;
END_VAR
VAR_OUTPUT
    OutA    : REAL;                   (* % *)
    OutB    : REAL;                   (* % *)
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    lo : REAL;
    hi : REAL;
END_VAR
lo := SplitPoint - Deadband / 2.0;
hi := SplitPoint + Deadband / 2.0;
Error := lo <= 0.0 OR hi >= 100.0;
IF Error THEN
    ErrorID := UDINT#1;
    OutA := 0.0;
    OutB := 0.0;
ELSE
    ErrorID := 0;
    IF InvertA THEN
        OutA := LIMIT(0.0, (lo - In) / lo * 100.0, 100.0);
    ELSE
        OutA := LIMIT(0.0, In / lo * 100.0, 100.0);
    END_IF;
    OutB := LIMIT(0.0, (In - hi) / (100.0 - hi) * 100.0, 100.0);
END_IF;
END_FUNCTION_BLOCK

(* F08.ALARM.SUMMARY: summary of up to 32 alarms (the State of RB_Alarm
   blocks): counts, a common lamp (flashing while any is unacknowledged,
   steady while any is active), a horn for each new unacknowledged alarm
   until silenced, and the first-out alarm. *)
FUNCTION_BLOCK RB_AlarmSummary
VAR_INPUT
    States  : ARRAY[1..32] OF RB_ALARM_STATE;
    Used    : DWORD := 16#FFFFFFFF;   (* bit k-1 set: alarm k is used *)
    Silence : BOOL;                   (* rising edge stops the horn *)
    Blink   : TIME := T#500ms;        (* half period of the flashing lamp *)
END_VAR
VAR_OUTPUT
    Active   : INT;                   (* alarms active (acknowledged or not) *)
    Unacked  : INT;                   (* alarms waiting for acknowledgement *)
    Lamp     : BOOL;
    Horn     : BOOL;
    FirstOut : INT;                   (* first alarm since all were normal; 0: none *)
END_VAR
VAR
    silenceEdge : R_TRIG;
    tBlink      : TON;
    phase       : BOOL;
    k           : INT;
    lastUnacked : INT;
    act         : BOOL;
END_VAR
silenceEdge(CLK := Silence);
Active := 0;
Unacked := 0;
FOR k := 1 TO 32 DO
    IF (Used AND SHL(DWORD#1, k - 1)) <> 0 THEN
        act := States[k] = RB_ALARM_STATE#ActiveUnack OR States[k] = RB_ALARM_STATE#ActiveAcked;
        IF act THEN
            Active := Active + 1;
            IF FirstOut = 0 THEN
                FirstOut := k;
            END_IF;
        END_IF;
        IF States[k] = RB_ALARM_STATE#ActiveUnack OR States[k] = RB_ALARM_STATE#ReturnedUnack THEN
            Unacked := Unacked + 1;
        END_IF;
    END_IF;
END_FOR;
IF Active = 0 AND Unacked = 0 THEN
    FirstOut := 0;
END_IF;
(* the horn sounds for every new unacknowledged alarm *)
IF Unacked > lastUnacked THEN
    Horn := TRUE;
END_IF;
IF silenceEdge.Q OR Unacked = 0 THEN
    Horn := FALSE;
END_IF;
lastUnacked := Unacked;
(* flashing: the phase toggles every Blink, the timer restarts at once *)
tBlink(IN := Unacked > 0, PT := Blink);
IF tBlink.Q THEN
    phase := NOT phase;
    tBlink(IN := FALSE, PT := Blink);
    tBlink(IN := TRUE, PT := Blink);
END_IF;
IF Unacked = 0 THEN
    phase := FALSE;
END_IF;
Lamp := (Unacked > 0 AND NOT phase) OR (Unacked = 0 AND Active > 0);
END_FUNCTION_BLOCK

(* F12.DIVERTER: a gate that sends each part straight on or into a branch.
   The destination (Divert) is read when the part reaches the gate eye; the
   gate holds its position until the part has left the eye plus PassTime,
   then returns straight. HoldPart stops the feeding conveyor while the gate
   is not yet in position. ErrorID 1 the gate did not reach its position
   within MoveTime. Safe state: gate de-energised (straight), HoldPart TRUE. *)
FUNCTION_BLOCK RB_Diverter
VAR_INPUT
    PartAtGate : BOOL;                (* eye in front of the gate *)
    Divert     : BOOL;                (* destination of the arriving part: TRUE branch *)
    FbDiverted : BOOL;
    FbStraight : BOOL;
    Feedback   : BOOL := TRUE;        (* FALSE: no gate position switches *)
    MoveTime   : TIME := T#2s;
    PassTime   : TIME := T#1s;        (* after the eye clears *)
    Reset      : BOOL;
END_VAR
VAR_OUTPUT
    Gate       : BOOL;                (* TRUE: gate to the branch *)
    HoldPart   : BOOL;                (* stop the feeding conveyor *)
    ToBranch   : UDINT;
    ToStraight : UDINT;
    Error      : BOOL;
    ErrorID    : UDINT;
END_VAR
VAR
    resetEdge : R_TRIG;
    arrive    : R_TRIG;
    leave     : F_TRIG;
    tPass     : TON;
    tMove     : TON;
    busy      : BOOL;
    passing   : BOOL;
    route     : BOOL;
    inPlace   : BOOL;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
    tMove(IN := FALSE, PT := MoveTime);  (* the gate gets a new MoveTime *)
END_IF;
arrive(CLK := PartAtGate);
leave(CLK := PartAtGate);
IF arrive.Q THEN
    route := Divert;
    busy := TRUE;
    passing := FALSE;
END_IF;
IF leave.Q AND busy THEN
    IF route THEN
        ToBranch := ToBranch + 1;
    ELSE
        ToStraight := ToStraight + 1;
    END_IF;
    passing := TRUE;
END_IF;
tPass(IN := passing, PT := PassTime);
IF tPass.Q THEN
    busy := FALSE;
END_IF;
Gate := busy AND route AND NOT Error;
IF Feedback THEN
    IF Gate THEN
        inPlace := FbDiverted AND NOT FbStraight;
    ELSE
        inPlace := FbStraight AND NOT FbDiverted;
    END_IF;
ELSE
    inPlace := TRUE;
END_IF;
tMove(IN := NOT inPlace, PT := MoveTime);
IF tMove.Q AND NOT Error THEN
    Error := TRUE;
    ErrorID := UDINT#1;
    Gate := FALSE;
END_IF;
HoldPart := Error OR (busy AND NOT passing AND NOT inPlace);
END_FUNCTION_BLOCK

(* F08.LIMITS: four limits on an analog value (high-high, high, low,
   low-low) with hysteresis, the usual source of process alarms. A limit
   becomes active beyond its value and clears Hysteresis back inside.
   ErrorID 1 limits not in order (LL <= L < H <= HH) or negative hysteresis;
   all outputs FALSE while the settings are wrong (the Error itself is the
   alarm). *)
FUNCTION_BLOCK RB_AnalogLimits
VAR_INPUT
    Value      : REAL;
    HH         : REAL := 95.0;
    H          : REAL := 85.0;
    L          : REAL := 15.0;
    LL         : REAL := 5.0;
    Hysteresis : REAL := 1.0;
    EnHH       : BOOL := TRUE;
    EnH        : BOOL := TRUE;
    EnL        : BOOL := TRUE;
    EnLL       : BOOL := TRUE;
END_VAR
VAR_OUTPUT
    HiHi    : BOOL;
    Hi      : BOOL;
    Lo      : BOOL;
    LoLo    : BOOL;
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
Error := LL > L OR L >= H OR H > HH OR Hysteresis < 0.0;
IF Error THEN
    ErrorID := UDINT#1;
    HiHi := FALSE;
    Hi := FALSE;
    Lo := FALSE;
    LoLo := FALSE;
ELSE
    ErrorID := 0;
    HiHi := EnHH AND (Value > HH OR (HiHi AND Value >= HH - Hysteresis));
    Hi := EnH AND (Value > H OR (Hi AND Value >= H - Hysteresis));
    Lo := EnL AND (Value < L OR (Lo AND Value <= L + Hysteresis));
    LoLo := EnLL AND (Value < LL OR (LoLo AND Value <= LL + Hysteresis));
END_IF;
END_FUNCTION_BLOCK

(* F06.RATIO: ratio control set point: SP = Ratio * Wild + Bias, limited to
   SPMin .. SPMax (blending, burner air/fuel, dosing proportional to a
   flow). ErrorID 1 SPMin > SPMax; SP is SPMin while the settings are
   wrong. *)
FUNCTION_BLOCK RB_Ratio
VAR_INPUT
    Wild  : REAL;                     (* the flow that is not controlled *)
    Ratio : REAL := 1.0;
    Bias  : REAL;
    SPMin : REAL;
    SPMax : REAL := 100.0;
END_VAR
VAR_OUTPUT
    SP      : REAL;                   (* set point for the controlled flow *)
    Limited : BOOL;                   (* SP is at a limit *)
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    raw : REAL;
END_VAR
Error := SPMin > SPMax;
raw := Ratio * Wild + Bias;
IF Error THEN
    ErrorID := UDINT#1;
    SP := SPMin;
    Limited := TRUE;
ELSE
    ErrorID := 0;
    SP := LIMIT(SPMin, raw, SPMax);
    Limited := raw < SPMin OR raw > SPMax;
END_IF;
END_FUNCTION_BLOCK

(* F04.MOTOR.2SPEED: a two-speed motor (two windings or Dahlander) with a
   slow and a fast contactor, built on RB_Motor. The two are never on
   together; a speed change switches both off for Changeover first. Faults
   as RB_Motor, with FbRunning = either contactor's auxiliary contact.
   Safe state: both contactors de-energised. *)
FUNCTION_BLOCK RB_MotorTwoSpeed
VAR_INPUT
    Mode         : RB_MODE := RB_MODE#Off;
    AutoRun      : BOOL;
    AutoFast     : BOOL;              (* TRUE fast, FALSE slow *)
    ManRun       : BOOL;
    ManFast      : BOOL;
    Interlock    : BOOL;
    Permissive   : BOOL := TRUE;
    FbSlow       : BOOL;
    FbFast       : BOOL;
    Overload     : BOOL;
    Feedback     : BOOL := TRUE;
    FeedbackTime : TIME := T#2s;
    RestartDelay : TIME := T#0s;
    Changeover   : TIME := T#500ms;   (* both off between speeds *)
    Reset        : BOOL;
END_VAR
VAR_OUTPUT
    Slow    : BOOL;                   (* slow contactor *)
    Fast    : BOOL;                   (* fast contactor *)
    Running : BOOL;
    AtFast  : BOOL;                   (* running fast *)
    Error   : BOOL;
    ErrorID : UDINT;
    Status  : RB_DEVICE_STATUS;
END_VAR
VAR
    motor     : RB_Motor;
    tGap      : TON;
    wantFast  : BOOL;
    sel       : BOOL;
    switching : BOOL;
END_VAR
motor(Mode := Mode, AutoRun := AutoRun, ManRun := ManRun, Interlock := Interlock,
      Permissive := Permissive, FbRunning := FbSlow OR FbFast, Overload := Overload,
      Feedback := Feedback, FeedbackTime := FeedbackTime, RestartDelay := RestartDelay,
      Reset := Reset);
wantFast := (Mode = RB_MODE#Auto AND AutoFast) OR (Mode = RB_MODE#Manual AND ManFast);
(* stopped, or starting from both off: take the requested speed at once *)
IF NOT motor.Run OR (NOT Slow AND NOT Fast AND NOT switching) THEN
    sel := wantFast;
    switching := FALSE;
ELSIF wantFast <> sel THEN
    switching := TRUE;
END_IF;
tGap(IN := switching, PT := Changeover);
IF tGap.Q THEN
    sel := wantFast;
    switching := FALSE;
END_IF;
Slow := motor.Run AND NOT switching AND NOT sel;
Fast := motor.Run AND NOT switching AND sel;
Running := motor.Running;
AtFast := Fast AND Running;
Error := motor.Error;
ErrorID := motor.ErrorID;
Status := motor.Status;
END_FUNCTION_BLOCK

(* F12.MERGE: two lanes merging into one. When the line downstream is
   clear, one waiting lane is released until its part has passed the merge
   eye; with both waiting the lanes alternate (or A has priority).
   ErrorID 1 no part passed within Timeout; releases off until Reset (safe
   state). *)
FUNCTION_BLOCK RB_Merge
VAR_INPUT
    WaitingA  : BOOL;                 (* a part waits in lane A *)
    WaitingB  : BOOL;
    Clear     : BOOL;                 (* the line downstream can take a part *)
    MergeEye  : BOOL;                 (* eye after the merge *)
    PriorityA : BOOL;                 (* FALSE: alternate *)
    Timeout   : TIME := T#10s;
    Reset     : BOOL;
END_VAR
VAR_OUTPUT
    ReleaseA : BOOL;
    ReleaseB : BOOL;
    FromA    : UDINT;
    FromB    : UDINT;
    Error    : BOOL;
    ErrorID  : UDINT;
END_VAR
VAR
    resetEdge : R_TRIG;
    passed    : F_TRIG;
    tRelease  : TON;
    lane      : INT;                  (* 0 none, 1 A, 2 B *)
    last      : INT;
END_VAR
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
    lane := 0;
END_IF;
passed(CLK := MergeEye);
IF passed.Q AND lane <> 0 THEN
    IF lane = 1 THEN
        FromA := FromA + 1;
    ELSE
        FromB := FromB + 1;
    END_IF;
    last := lane;
    lane := 0;
END_IF;
IF lane = 0 AND Clear AND NOT Error THEN
    IF WaitingA AND (NOT WaitingB OR PriorityA OR last <> 1) THEN
        lane := 1;
    ELSIF WaitingB THEN
        lane := 2;
    END_IF;
    (* each release gets its own Timeout *)
    tRelease(IN := FALSE, PT := Timeout);
END_IF;
tRelease(IN := lane <> 0, PT := Timeout);
IF tRelease.Q AND NOT Error THEN
    Error := TRUE;
    ErrorID := UDINT#1;
    lane := 0;
END_IF;
ReleaseA := lane = 1;
ReleaseB := lane = 2;
END_FUNCTION_BLOCK

(* F03.SCHEDULE: a weekly time switch: Out between OnTime and OffTime on
   the selected days (a window past midnight belongs to the day it
   started). The application supplies the time of day and the weekday from
   its clock. ErrorID 1 Day outside 1 .. 7; Out FALSE. *)
FUNCTION_BLOCK RB_Schedule
VAR_INPUT
    Now     : TOD;
    Day     : INT := 1;               (* 1 Monday .. 7 Sunday *)
    OnTime  : TOD := TOD#06:00:00;
    OffTime : TOD := TOD#22:00:00;
    Days    : BYTE := 16#7F;          (* bit d-1 set: day d selected *)
    Enable  : BOOL := TRUE;
END_VAR
VAR_OUTPUT
    Out     : BOOL;
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    startDay : INT;
    inWindow : BOOL;
END_VAR
Error := Day < 1 OR Day > 7;
startDay := Day;
IF OnTime <= OffTime THEN
    inWindow := Now >= OnTime AND Now < OffTime;
ELSIF Now < OffTime THEN
    inWindow := TRUE;                        (* after midnight *)
    startDay := (Day + 5) MOD 7 + 1;         (* the day before *)
ELSE
    inWindow := Now >= OnTime;
END_IF;
IF Error THEN
    ErrorID := UDINT#1;
    Out := FALSE;
ELSE
    ErrorID := 0;
    Out := Enable AND inWindow AND (SHR(Days, startDay - 1) AND BYTE#1) <> BYTE#0;
END_IF;
END_FUNCTION_BLOCK

(* F06.CASCADE: cascade control from two RB_PID: the outer (primary) loop
   sets the set point of the inner (secondary) loop, whose output drives
   the actuator. Auto with Cascade: both loops in Auto. Auto without
   Cascade: the inner loop on InnerSP. Manual: Out = ManValue. In Manual
   and Off the inner set point tracks the inner PV, and whenever the outer
   loop does not drive the inner set point its output tracks the inner PV,
   so switching to Auto and to cascade is bumpless. Errors as RB_PID (ErrorID of the
   inner loop, or 10 + that of the outer loop); Out = OutMin on an error. *)
FUNCTION_BLOCK RB_Cascade
VAR_INPUT
    Mode       : RB_MODE := RB_MODE#Off;
    Cascade    : BOOL := TRUE;        (* FALSE: inner loop alone on InnerSP *)
    SP         : REAL;                (* primary set point *)
    PV         : REAL;                (* primary process value *)
    InnerSP    : REAL;                (* inner set point without cascade *)
    InnerPV    : REAL;                (* secondary process value *)
    KpOuter    : REAL := 1.0;
    TiOuter    : TIME := T#0s;
    KpInner    : REAL := 1.0;
    TiInner    : TIME := T#0s;
    InnerSPMin : REAL;                (* range of the inner set point *)
    InnerSPMax : REAL := 100.0;
    OutMin     : REAL;
    OutMax     : REAL := 100.0;
    ManValue   : REAL;
    Reset      : BOOL;
END_VAR
VAR_OUTPUT
    Out         : REAL;
    InnerSPUsed : REAL;               (* the inner set point in use *)
    InCascade   : BOOL;
    Saturated   : BOOL;               (* the inner loop is at an output limit *)
    Error       : BOOL;
    ErrorID     : UDINT;
END_VAR
VAR
    outer     : RB_PID;
    inner     : RB_PID;
    outerMode : RB_MODE;
END_VAR
InCascade := Mode = RB_MODE#Auto AND Cascade;
IF InCascade THEN
    outerMode := RB_MODE#Auto;
ELSE
    outerMode := RB_MODE#Manual;
END_IF;
outer(Mode := outerMode, SP := SP, PV := PV, Kp := KpOuter, Ti := TiOuter,
      OutMin := InnerSPMin, OutMax := InnerSPMax, ManValue := InnerPV, Reset := Reset);
IF InCascade THEN
    InnerSPUsed := outer.Out;
ELSIF Mode = RB_MODE#Auto THEN
    InnerSPUsed := InnerSP;
ELSE
    InnerSPUsed := InnerPV;           (* set-point tracking in Manual and Off *)
END_IF;
inner(Mode := Mode, SP := InnerSPUsed, PV := InnerPV, Kp := KpInner, Ti := TiInner,
      OutMin := OutMin, OutMax := OutMax, ManValue := ManValue, Reset := Reset);
Out := inner.Out;
Saturated := inner.Saturated;
Error := inner.Error OR outer.Error;
IF inner.Error THEN
    ErrorID := inner.ErrorID;
ELSIF outer.Error THEN
    ErrorID := 10 + outer.ErrorID;
ELSE
    ErrorID := 0;
END_IF;
END_FUNCTION_BLOCK

(* F04.GROUP: duty/standby for up to 4 identical units (pumps, fans,
   compressors): runs Demand units, choosing the available ones with the
   fewest run hours, starts at most one unit per StageDelay, replaces a
   unit that becomes unavailable at once, and stops the one with the most
   hours when demand falls. Shortfall when not enough units are
   available. *)
FUNCTION_BLOCK RB_DutyStandby
VAR_INPUT
    Demand     : INT;                 (* units wanted, 0 .. 4 *)
    Available  : ARRAY[1..4] OF BOOL; (* healthy and in Auto *)
    Hours      : ARRAY[1..4] OF REAL; (* run hours, e.g. RB_RunHours *)
    Used       : INT := 4;            (* units fitted, 1 .. 4 *)
    StageDelay : TIME := T#0s;        (* between two starts *)
END_VAR
VAR_OUTPUT
    Run       : ARRAY[1..4] OF BOOL;  (* AutoRun of each unit *)
    Running   : INT;
    Shortfall : BOOL;
END_VAR
VAR
    tStage  : TON;
    k       : INT;
    best    : INT;
    lost    : BOOL;
    want    : INT;
    n       : INT;
END_VAR
n := LIMIT(1, Used, 4);
want := LIMIT(0, Demand, n);
(* a running unit that is no longer available stops; its replacement may
   start at once *)
lost := FALSE;
Running := 0;
FOR k := 1 TO 4 DO
    IF Run[k] AND (k > n OR NOT Available[k]) THEN
        Run[k] := FALSE;
        lost := TRUE;
    END_IF;
    IF Run[k] THEN
        Running := Running + 1;
    END_IF;
END_FOR;
tStage(IN := TRUE, PT := StageDelay);
IF Running < want AND (tStage.Q OR lost OR Running = 0) THEN
    best := 0;
    FOR k := 1 TO n DO
        IF Available[k] AND NOT Run[k] THEN
            IF best = 0 THEN
                best := k;
            ELSIF Hours[k] < Hours[best] THEN
                best := k;
            END_IF;
        END_IF;
    END_FOR;
    IF best > 0 THEN
        Run[best] := TRUE;
        Running := Running + 1;
        tStage(IN := FALSE, PT := StageDelay);
        tStage(IN := TRUE, PT := StageDelay);
    END_IF;
END_IF;
WHILE Running > want DO
    best := 0;
    FOR k := 1 TO n DO
        IF Run[k] THEN
            IF best = 0 THEN
                best := k;
            ELSIF Hours[k] > Hours[best] THEN
                best := k;
            END_IF;
        END_IF;
    END_FOR;
    Run[best] := FALSE;
    Running := Running - 1;
END_WHILE;
(* units that could still run *)
best := 0;
FOR k := 1 TO n DO
    IF Available[k] THEN
        best := best + 1;
    END_IF;
END_FOR;
Shortfall := best < want;
END_FUNCTION_BLOCK

(* F09.TOTAL: a totaliser: integrates a rate (flow, power) over time to a
   total (volume, energy), with a low-flow cut-off and a batch total with a
   preset (dosing a quantity). Rate is in units per TimeBase (m3/h with
   T#1h, kW -> kWh with T#1h, l/min with T#1m). *)
FUNCTION_BLOCK RB_Totalizer
VAR_INPUT
    Rate       : REAL;
    TimeBase   : TIME := T#1h;
    LowCut     : REAL;                (* rates at or below this count as 0 *)
    Hold       : BOOL;                (* TRUE: do not count *)
    StartBatch : BOOL;                (* rising edge: batch total := 0 *)
    Preset     : LREAL;               (* batch quantity; 0: none *)
    Reset      : BOOL;                (* rising edge: total := 0 *)
END_VAR
VAR_OUTPUT
    Total      : LREAL;
    BatchTotal : LREAL;
    BatchDone  : BOOL;                (* BatchTotal reached Preset *)
    Counting   : BOOL;
END_VAR
VAR
    cyc        : RB_CycleTime;
    batchEdge  : R_TRIG;
    resetEdge  : R_TRIG;
    delta      : LREAL;
    baseSec    : LREAL;
END_VAR
cyc();
batchEdge(CLK := StartBatch);
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Total := 0.0;
END_IF;
IF batchEdge.Q THEN
    BatchTotal := 0.0;
END_IF;
baseSec := TIME_TO_LREAL(TimeBase) / 1000.0;
Counting := NOT Hold AND Rate > LowCut AND baseSec > 0.0;
IF Counting THEN
    delta := REAL_TO_LREAL(Rate) * cyc.Seconds / baseSec;
    Total := Total + delta;
    BatchTotal := BatchTotal + delta;
END_IF;
BatchDone := Preset > 0.0 AND BatchTotal >= Preset;
END_FUNCTION_BLOCK

(* F09.OEE: overall equipment effectiveness of a machine: availability
   (running time / planned time), performance (ideal cycle time x parts /
   running time) and quality (good parts / all parts), each 0 .. 1, and
   their product. Counts from the rising edges of Good and Reject. *)
FUNCTION_BLOCK RB_OEE
VAR_INPUT
    Planned    : BOOL;                (* planned production time *)
    Running    : BOOL;                (* producing *)
    Good       : BOOL;                (* rising edge: a good part *)
    Reject     : BOOL;                (* rising edge: a rejected part *)
    IdealCycle : TIME := T#1s;        (* ideal time per part *)
    Reset      : BOOL;                (* rising edge: start a new period *)
END_VAR
VAR_OUTPUT
    Availability : REAL;
    Performance  : REAL;
    Quality      : REAL;
    OEE          : REAL;
    PlannedTime  : LREAL;             (* s *)
    RunTime      : LREAL;             (* s *)
    GoodCount    : UDINT;
    RejectCount  : UDINT;
END_VAR
VAR
    cyc       : RB_CycleTime;
    goodEdge  : R_TRIG;
    rejEdge   : R_TRIG;
    resetEdge : R_TRIG;
    parts     : LREAL;
END_VAR
cyc();
goodEdge(CLK := Good);
rejEdge(CLK := Reject);
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    PlannedTime := 0.0;
    RunTime := 0.0;
    GoodCount := 0;
    RejectCount := 0;
END_IF;
IF Planned THEN
    PlannedTime := PlannedTime + cyc.Seconds;
    IF Running THEN
        RunTime := RunTime + cyc.Seconds;
    END_IF;
END_IF;
IF goodEdge.Q THEN
    GoodCount := GoodCount + 1;
END_IF;
IF rejEdge.Q THEN
    RejectCount := RejectCount + 1;
END_IF;
parts := UDINT_TO_LREAL(GoodCount + RejectCount);
Availability := 0.0;
Performance := 0.0;
Quality := 0.0;
IF PlannedTime > 0.0 THEN
    Availability := LREAL_TO_REAL(RunTime / PlannedTime);
END_IF;
IF RunTime > 0.0 THEN
    Performance := LREAL_TO_REAL(MIN(1.0, TIME_TO_LREAL(IdealCycle) / 1000.0 * parts / RunTime));
END_IF;
IF parts > 0.0 THEN
    Quality := LREAL_TO_REAL(UDINT_TO_LREAL(GoodCount) / parts);
END_IF;
OEE := Availability * Performance * Quality;
END_FUNCTION_BLOCK

(* F06.PROFILE: a set-point program of up to 8 segments, each a ramp to a
   target in RampTime and a soak for SoakTime (ovens, kilns, heat
   treatment, sterilisers). Start begins at the present PV. With Band > 0
   the soak time counts only while PV is within Band of SP (guaranteed
   soak). Hold freezes the program. ErrorID 1 Count outside 1 .. 8; the
   program does not start. *)
FUNCTION_BLOCK RB_SetpointProfile
VAR_INPUT
    Start     : BOOL;                 (* rising edge: segment 1, startSP PV *)
    Hold      : BOOL;                 (* TRUE: SP and timers frozen *)
    Abort     : BOOL;                 (* rising edge: end the program *)
    PV        : REAL;
    Count     : INT := 1;             (* segments used, 1 .. 8 *)
    Targets   : ARRAY[1..8] OF REAL;
    RampTimes : ARRAY[1..8] OF TIME;
    SoakTimes : ARRAY[1..8] OF TIME;
    Band      : REAL;                 (* guaranteed soak; 0: off *)
END_VAR
VAR_OUTPUT
    SP      : REAL;
    Segment : INT;                    (* 0: not running *)
    Soaking : BOOL;
    Busy    : BOOL;
    Done    : BOOL;                   (* the program completed *)
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    startEdge : R_TRIG;
    abortEdge : R_TRIG;
    cyc       : RB_CycleTime;
    startSP      : REAL;
    t         : TIME;                 (* in the ramp or soak *)
END_VAR
cyc();
startEdge(CLK := Start);
abortEdge(CLK := Abort);
IF startEdge.Q THEN
    Error := Count < 1 OR Count > 8;
    Done := FALSE;
    Soaking := FALSE;
    t := T#0s;
    IF Error THEN
        ErrorID := UDINT#1;
        Segment := 0;
        Busy := FALSE;
    ELSE
        ErrorID := 0;
        Segment := 1;
        Busy := TRUE;
        startSP := PV;
        SP := PV;
    END_IF;
ELSIF abortEdge.Q THEN
    Segment := 0;
    Busy := FALSE;
    Soaking := FALSE;
ELSIF Busy AND NOT Hold THEN
    IF NOT Soaking THEN
        t := t + cyc.Elapsed;
        IF t >= RampTimes[Segment] THEN
            SP := Targets[Segment];
            Soaking := TRUE;
            t := T#0s;
        ELSE
            SP := startSP + (Targets[Segment] - startSP) * LREAL_TO_REAL(TIME_TO_LREAL(t) / TIME_TO_LREAL(RampTimes[Segment]));
        END_IF;
    ELSE
        IF Band <= 0.0 OR ABS(PV - SP) <= Band THEN
            t := t + cyc.Elapsed;
        END_IF;
        IF t >= SoakTimes[Segment] THEN
            startSP := Targets[Segment];
            Soaking := FALSE;
            t := T#0s;
            IF Segment >= Count THEN
                Segment := 0;
                Busy := FALSE;
                Done := TRUE;
            ELSE
                Segment := Segment + 1;
            END_IF;
        END_IF;
    END_IF;
END_IF;
END_FUNCTION_BLOCK

(* F05.HOMING: a homing sequence for an axis without position feedback
   other than a home switch (a positioning motor, a lift, a turntable):
   move towards the switch, then away slowly until it releases; the axis
   is then homed. ErrorID 1 the switch was not reached within Timeout, 2 it
   did not release within Timeout; outputs off (safe state) until Reset. *)
FUNCTION_BLOCK RB_Homing
VAR_INPUT
    Start      : BOOL;                (* rising edge: home *)
    Abort      : BOOL;                (* TRUE: stop now *)
    HomeSwitch : BOOL;
    Timeout    : TIME := T#30s;       (* per phase *)
    Reset      : BOOL;                (* rising edge clears a fault *)
END_VAR
VAR_OUTPUT
    MoveToHome : BOOL;                (* towards the switch *)
    MoveAway   : BOOL;                (* away from the switch *)
    Slow       : BOOL;                (* creep speed *)
    Homed      : BOOL;
    Busy       : BOOL;
    Error      : BOOL;
    ErrorID    : UDINT;
END_VAR
VAR
    startEdge : R_TRIG;
    resetEdge : R_TRIG;
    tPhase    : TON;
    phase     : INT;                  (* 0 idle, 1 seek, 2 back off *)
END_VAR
startEdge(CLK := Start);
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Error := FALSE;
    ErrorID := 0;
END_IF;
IF startEdge.Q AND NOT Error AND NOT Abort THEN
    Homed := FALSE;
    phase := 1;
    tPhase(IN := FALSE, PT := Timeout);
END_IF;
IF phase = 1 AND HomeSwitch THEN
    phase := 2;
    tPhase(IN := FALSE, PT := Timeout);
END_IF;
IF phase = 2 AND NOT HomeSwitch THEN
    phase := 0;
    Homed := TRUE;
END_IF;
IF Abort THEN
    phase := 0;
END_IF;
tPhase(IN := phase <> 0, PT := Timeout);
IF tPhase.Q THEN
    Error := TRUE;
    ErrorID := INT_TO_UDINT(phase);
    phase := 0;
END_IF;
MoveToHome := phase = 1;
MoveAway := phase = 2;
Slow := phase = 2;
Busy := phase <> 0;
END_FUNCTION_BLOCK

(* F11.LOG: records a value every Interval into a ring of the last 64
   samples, with the minimum, maximum and average of what is stored (a
   trend for the HMI, a quick diagnosis record). The first sample is taken
   when logging starts. *)
FUNCTION_BLOCK RB_DataLog
VAR_INPUT
    Value    : REAL;
    Interval : TIME := T#1s;
    Enable   : BOOL := TRUE;
    Clear    : BOOL;                  (* rising edge: empty the log *)
END_VAR
VAR_OUTPUT
    Samples : ARRAY[1..64] OF REAL;
    Newest  : INT;                    (* index of the newest sample; 0: none *)
    Count   : INT;
    Minimum : REAL;
    Maximum : REAL;
    Average : REAL;
END_VAR
VAR
    tSample   : TON;
    clearEdge : R_TRIG;
    k         : INT;
    sum       : LREAL;
END_VAR
clearEdge(CLK := Clear);
IF clearEdge.Q THEN
    Count := 0;
    Newest := 0;
END_IF;
tSample(IN := Enable, PT := Interval);
IF Enable AND (Count = 0 OR tSample.Q) THEN
    Newest := Newest MOD 64 + 1;
    Samples[Newest] := Value;
    Count := MIN(Count + 1, 64);
    tSample(IN := FALSE, PT := Interval);
    tSample(IN := TRUE, PT := Interval);
END_IF;
IF Count > 0 THEN
    Minimum := Samples[Newest];
    Maximum := Samples[Newest];
    sum := 0.0;
    FOR k := 1 TO Count DO
        Minimum := MIN(Minimum, Samples[k]);
        Maximum := MAX(Maximum, Samples[k]);
        sum := sum + REAL_TO_LREAL(Samples[k]);
    END_FOR;
    Average := LREAL_TO_REAL(sum / INT_TO_LREAL(Count));
ELSE
    Minimum := 0.0;
    Maximum := 0.0;
    Average := 0.0;
END_IF;
END_FUNCTION_BLOCK

(* F01.SCALE.OUT: an engineering value to an analog output word (the
   reverse of RB_Scale): limited to the engineering range, scaled to
   RawMin .. RawMax and rounded. Fault TRUE writes FailValue instead (safe
   state chosen per output). ErrorID 1 EngMin = EngMax; the output is
   RawMin. *)
FUNCTION_BLOCK RB_ScaleOut
VAR_INPUT
    Value     : REAL;
    EngMin    : REAL;
    EngMax    : REAL := 100.0;
    RawMin    : REAL;
    RawMax    : REAL := 27648.0;
    Fault     : BOOL;                 (* TRUE: write FailValue *)
    FailValue : REAL;                 (* engineering units *)
END_VAR
VAR_OUTPUT
    Raw     : INT;
    Limited : BOOL;                   (* Value was outside the range *)
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    v  : REAL;
    lo : REAL;
    hi : REAL;
END_VAR
Error := EngMin = EngMax;
IF Error THEN
    ErrorID := UDINT#1;
    Raw := REAL_TO_INT(RawMin);
    Limited := FALSE;
ELSE
    ErrorID := 0;
    IF Fault THEN
        v := FailValue;
    ELSE
        v := Value;
    END_IF;
    lo := MIN(EngMin, EngMax);
    hi := MAX(EngMin, EngMax);
    Limited := v < lo OR v > hi;
    v := LIMIT(lo, v, hi);
    Raw := REAL_TO_INT(RawMin + (v - EngMin) * (RawMax - RawMin) / (EngMax - EngMin));
END_IF;
END_FUNCTION_BLOCK

(* F05.DRUM: a drum sequencer: up to 16 steps, each with a pattern of 16
   outputs (a WORD) and a time; a step with time T#0s waits for Next. Run
   advances by time (paused while FALSE), a rising edge of Next advances
   at once. After the last step it starts again (Cyclic) or stays there
   with Done. ErrorID 1 Count outside 1 .. 16; Out is 0. *)
FUNCTION_BLOCK RB_Drum
VAR_INPUT
    Run      : BOOL;                  (* TRUE: step times run *)
    Next     : BOOL;                  (* rising edge: next step now *)
    Reset    : BOOL;                  (* rising edge: back to step 1 *)
    Patterns : ARRAY[1..16] OF WORD;
    Times    : ARRAY[1..16] OF TIME;  (* T#0s: wait for Next *)
    Count    : INT := 16;             (* steps used, 1 .. 16 *)
    Cyclic   : BOOL := TRUE;
END_VAR
VAR_OUTPUT
    StepNo   : INT;
    Out      : WORD;
    StepTime : TIME;                  (* time spent in this step *)
    Done     : BOOL;                  (* not cyclic: the last step ended *)
    Error    : BOOL;
    ErrorID  : UDINT;
END_VAR
VAR
    nextEdge  : R_TRIG;
    resetEdge : R_TRIG;
    cyc       : RB_CycleTime;
    t         : TIME;
    advance   : BOOL;
END_VAR
cyc();
nextEdge(CLK := Next);
resetEdge(CLK := Reset);
Error := Count < 1 OR Count > 16;
IF Error THEN
    ErrorID := UDINT#1;
    StepNo := 0;
    Out := 0;
ELSE
    ErrorID := 0;
    IF StepNo < 1 OR StepNo > Count OR resetEdge.Q THEN
        StepNo := 1;
        t := T#0s;
        Done := FALSE;
    ELSE
        IF Run AND NOT Done THEN
            t := t + cyc.Elapsed;
        END_IF;
        advance := nextEdge.Q OR (Run AND Times[StepNo] > T#0s AND t >= Times[StepNo]);
        IF advance AND NOT Done THEN
            t := T#0s;
            IF StepNo < Count THEN
                StepNo := StepNo + 1;
            ELSIF Cyclic THEN
                StepNo := 1;
            ELSE
                Done := TRUE;
            END_IF;
        END_IF;
    END_IF;
    Out := Patterns[StepNo];
END_IF;
StepTime := t;
END_FUNCTION_BLOCK

(* F03.BLINK: a pulse generator: Out on for OnTime, off for OffTime, while
   Enable (warning lamps, horns, lubrication pulses). Starts on; the phase
   is kept exactly (TIME arithmetic). *)
FUNCTION_BLOCK RB_Blink
VAR_INPUT
    Enable  : BOOL;
    OnTime  : TIME := T#500ms;
    OffTime : TIME := T#500ms;
END_VAR
VAR_OUTPUT
    Out    : BOOL;
    Pulses : UDINT;                   (* on phases since the block started *)
END_VAR
VAR
    cyc     : RB_CycleTime;
    t       : TIME;
    running : BOOL;
END_VAR
cyc();
IF NOT Enable THEN
    Out := FALSE;
    running := FALSE;
ELSIF NOT running THEN
    running := TRUE;
    Out := TRUE;
    Pulses := Pulses + 1;
    t := T#0s;
ELSE
    t := t + cyc.Elapsed;
    IF Out AND t >= OnTime THEN
        Out := FALSE;
        t := t - OnTime;
    ELSIF NOT Out AND t >= OffTime THEN
        Out := TRUE;
        Pulses := Pulses + 1;
        t := t - OffTime;
    END_IF;
END_IF;
END_FUNCTION_BLOCK

(* F06.PWM: time-proportioning output: a controller output of 0 .. 100 %
   as an on/off signal with a fixed Period (heaters with contactors or
   solid-state relays, dosing pumps). The duty is taken at the start of
   each period; pulses shorter than MinPulse are left out (off) or filled
   up (on for the whole period). ErrorID 1 Period T#0s; Out FALSE. *)
FUNCTION_BLOCK RB_PWM
VAR_INPUT
    In       : REAL;                  (* % *)
    Period   : TIME := T#2s;
    MinPulse : TIME := T#0s;
    Enable   : BOOL := TRUE;
END_VAR
VAR_OUTPUT
    Out     : BOOL;
    OnTime  : TIME;                   (* on time in this period *)
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    cyc     : RB_CycleTime;
    t       : TIME;
    running : BOOL;
    newPeriod : BOOL;
END_VAR
cyc();
Error := Period <= T#0s;
IF Error THEN
    ErrorID := UDINT#1;
ELSE
    ErrorID := 0;
END_IF;
IF Error OR NOT Enable THEN
    Out := FALSE;
    running := FALSE;
    OnTime := T#0s;
ELSE
    newPeriod := NOT running;
    IF running THEN
        t := t + cyc.Elapsed;
        IF t >= Period THEN
            t := t - Period;
            newPeriod := TRUE;
        END_IF;
    ELSE
        t := T#0s;
        running := TRUE;
    END_IF;
    IF newPeriod THEN
        OnTime := LREAL_TO_TIME(TIME_TO_LREAL(Period) * REAL_TO_LREAL(LIMIT(0.0, In, 100.0)) / 100.0);
        IF OnTime < MinPulse THEN
            OnTime := T#0s;
        ELSIF Period - OnTime < MinPulse THEN
            OnTime := Period;
        END_IF;
    END_IF;
    Out := t < OnTime;
END_IF;
END_FUNCTION_BLOCK

(* F01.PULSE: a rate and a total from a pulse input (flow meters, energy
   meters, counting wheels): pulses are counted over a gate time Window;
   at the end of each window Rate is updated. Factor is the quantity per
   pulse; Rate is in units per TimeBase. The pulse must stay on and off for
   at least one PLC cycle each. *)
FUNCTION_BLOCK RB_PulseRate
VAR_INPUT
    Pulse    : BOOL;
    Factor   : LREAL := 1.0;          (* units per pulse *)
    Window   : TIME := T#1s;
    TimeBase : TIME := T#1h;          (* m3/h: T#1h; l/min: T#1m *)
    Reset    : BOOL;                  (* rising edge: Total := 0 *)
END_VAR
VAR_OUTPUT
    Rate    : LREAL;
    Total   : LREAL;
    Pulses  : UDINT;                  (* pulses in the current window *)
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    cyc       : RB_CycleTime;
    edge      : R_TRIG;
    resetEdge : R_TRIG;
    t         : TIME;
END_VAR
cyc();
edge(CLK := Pulse);
resetEdge(CLK := Reset);
IF resetEdge.Q THEN
    Total := 0.0;
END_IF;
Error := Window <= T#0s;
IF Error THEN
    ErrorID := UDINT#1;
    Rate := 0.0;
    Pulses := 0;
    t := T#0s;
ELSE
    ErrorID := 0;
    IF edge.Q THEN
        Pulses := Pulses + 1;
        Total := Total + Factor;
    END_IF;
    t := t + cyc.Elapsed;
    IF t >= Window THEN
        Rate := UDINT_TO_LREAL(Pulses) * Factor * TIME_TO_LREAL(TimeBase) / TIME_TO_LREAL(Window);
        Pulses := 0;
        t := t - Window;
    END_IF;
END_IF;
END_FUNCTION_BLOCK

(* F11.TRACK: part tracking on a conveyor with a shift register of 64
   positions (one per pitch or encoder step): each Shift moves every entry
   one position on and puts InValue (0: no part, else a part ID or a code
   such as "reject") into position 1. AtRead is the entry at ReadPos, where
   an ejector or a station acts; Remove clears it there. *)
FUNCTION_BLOCK RB_ShiftTrack
VAR_INPUT
    Shift   : BOOL;                   (* rising edge: one position on *)
    InValue : DINT;                   (* entry for position 1 at the shift *)
    ReadPos : INT := 10;              (* 1 .. 64 *)
    Remove  : BOOL;                   (* rising edge: clear the entry at ReadPos *)
    Clear   : BOOL;                   (* rising edge: clear all *)
END_VAR
VAR_OUTPUT
    Positions : ARRAY[1..64] OF DINT;
    AtRead    : DINT;
    Occupied  : INT;                  (* non-zero entries *)
    Error     : BOOL;
    ErrorID   : UDINT;
END_VAR
VAR
    shiftEdge  : R_TRIG;
    removeEdge : R_TRIG;
    clearEdge  : R_TRIG;
    k          : INT;
END_VAR
shiftEdge(CLK := Shift);
removeEdge(CLK := Remove);
clearEdge(CLK := Clear);
Error := ReadPos < 1 OR ReadPos > 64;
IF clearEdge.Q THEN
    FOR k := 1 TO 64 DO
        Positions[k] := 0;
    END_FOR;
END_IF;
IF shiftEdge.Q THEN
    FOR k := 64 TO 2 BY -1 DO
        Positions[k] := Positions[k - 1];
    END_FOR;
    Positions[1] := InValue;
END_IF;
IF Error THEN
    ErrorID := UDINT#1;
    AtRead := 0;
ELSE
    ErrorID := 0;
    IF removeEdge.Q THEN
        Positions[ReadPos] := 0;
    END_IF;
    AtRead := Positions[ReadPos];
END_IF;
Occupied := 0;
FOR k := 1 TO 64 DO
    IF Positions[k] <> 0 THEN
        Occupied := Occupied + 1;
    END_IF;
END_FOR;
END_FUNCTION_BLOCK

(* F01.VOTE: one measurement from three redundant transmitters: the median
   of the healthy ones (three), their average (two) or the one left; a
   transmitter differing from the result by more than MaxDev is flagged.
   ErrorID 1 no healthy transmitter; Value holds its last good value. *)
FUNCTION_BLOCK RB_Vote2oo3
VAR_INPUT
    A, B, C    : REAL;
    OkA        : BOOL := TRUE;        (* signal healthy, e.g. NOT RB_Scale.Error *)
    OkB        : BOOL := TRUE;
    OkC        : BOOL := TRUE;
    MaxDev     : REAL := 2.0;
END_VAR
VAR_OUTPUT
    Value   : REAL;
    Healthy : INT;                    (* transmitters used *)
    DevA    : BOOL;
    DevB    : BOOL;
    DevC    : BOOL;
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
VAR
    sum : REAL;
END_VAR
Healthy := BOOL_TO_INT(OkA) + BOOL_TO_INT(OkB) + BOOL_TO_INT(OkC);
Error := Healthy = 0;
IF Error THEN
    ErrorID := UDINT#1;
ELSE
    ErrorID := 0;
    IF Healthy = 3 THEN
        Value := MAX(MIN(A, B), MIN(MAX(A, B), C));
    ELSE
        sum := 0.0;
        IF OkA THEN sum := sum + A; END_IF;
        IF OkB THEN sum := sum + B; END_IF;
        IF OkC THEN sum := sum + C; END_IF;
        Value := sum / INT_TO_REAL(Healthy);
    END_IF;
END_IF;
DevA := OkA AND NOT Error AND ABS(A - Value) > MaxDev;
DevB := OkB AND NOT Error AND ABS(B - Value) > MaxDev;
DevC := OkC AND NOT Error AND ABS(C - Value) > MaxDev;
END_FUNCTION_BLOCK

(* F02.BYPASS: a maintenance bypass of one condition (an interlock or a
   permissive), allowed by a key switch and limited in time: Out is the
   condition, or TRUE while the bypass is active. The bypass ends after
   MaxTime, on Cancel, or when the key switch is turned back. Not for
   safety functions. *)
FUNCTION_BLOCK RB_Bypass
VAR_INPUT
    Cond    : BOOL;                   (* the real condition, TRUE = ok *)
    Request : BOOL;                   (* rising edge: start the bypass *)
    Permit  : BOOL;                   (* key switch *)
    Cancel  : BOOL;                   (* rising edge: end it *)
    MaxTime : TIME := T#30m;
END_VAR
VAR_OUTPUT
    Out       : BOOL;
    Active    : BOOL;
    Remaining : TIME;
    Uses      : UDINT;                (* times the bypass was started *)
    Expired   : BOOL;                 (* TRUE for one call when MaxTime ran out *)
END_VAR
VAR
    requestEdge : R_TRIG;
    cancelEdge  : R_TRIG;
    tActive     : TON;
END_VAR
requestEdge(CLK := Request);
cancelEdge(CLK := Cancel);
IF requestEdge.Q AND Permit AND NOT Active THEN
    Active := TRUE;
    Uses := Uses + 1;
END_IF;
IF cancelEdge.Q OR NOT Permit THEN
    Active := FALSE;
END_IF;
tActive(IN := Active, PT := MaxTime);
Expired := tActive.Q;
IF tActive.Q THEN
    Active := FALSE;
END_IF;
IF Active THEN
    Remaining := MaxTime - tActive.ET;
ELSE
    Remaining := T#0s;
END_IF;
Out := Cond OR Active;
END_FUNCTION_BLOCK
