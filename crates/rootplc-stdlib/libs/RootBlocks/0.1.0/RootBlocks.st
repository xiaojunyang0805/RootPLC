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
