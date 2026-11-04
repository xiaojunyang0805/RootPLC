(* Tc2_MC2 compatibility library for RootPLC (see library.toml): the axis
   interface and the PLCopen motion function blocks. Motion needs the NC
   (TwinCAT motion runtime): the function blocks are declared only, and the
   axis data keep their initial values. The AT %I* / %Q* mapping of AXIS_REF
   is left out. *)

(* DEFAULT_HOME_POSITION asks MC_Home for the reference position set in the
   TwinCAT System Manager; its value is not published, the one here is
   RootPLC's marker. *)
VAR_GLOBAL CONSTANT
    DEFAULT_HOME_POSITION : LREAL := 1.0E28;
END_VAR

FUNCTION_BLOCK AXIS_REF
VAR_INPUT
    PlcToNc : PLCTONC_AXIS_REF;
END_VAR
VAR_OUTPUT
    NcToPlc : NCTOPLC_AXIS_REF;
    ADS : ST_AdsAddress;
    Status : ST_AxisStatus;
    DriveAddress : ST_DriveAddress;
END_VAR
(* ReadStatus updates Status from NcToPlc in TwinCAT; without the NC there
   is nothing to read. *)
ACTION ReadStatus:
END_ACTION
END_FUNCTION_BLOCK

TYPE NCTOPLC_AXIS_REF :
STRUCT
    StateDWord                    : NCTOPLC_AXIS_REF_STATE; (* Status double word *)
    ErrorCode                     : DWORD; (* Axis error code *)
    AxisState                     : DWORD; (* Axis moving status *)
    AxisModeConfirmation          : DWORD; (* Axis mode confirmation (feedback from NC) *)
    HomingState                   : DWORD; (* State of axis calibration (homing) *)
    CoupleState                   : DWORD; (* Axis coupling state *)
    SvbEntries                    : DWORD; (* SVB entries/orders (SVB = Set preparation task) *)
    SafEntries                    : DWORD; (* SAF entries/orders (SAF = Set execution task) *)
    AxisId                        : DWORD; (* Axis ID *)
    OpModeDWord                   : NCTOPLC_AXIS_REF_OPMODE; (* Current operation mode *)
    ActPos                        : LREAL; (* Actual position (absolut value from NC) *)
    ModuloActPos                  : LREAL; (* Actual modulo position *)
    ActiveControlLoopIndex        : WORD; (* Active control loop index *)
    ControlLoopIndex              : WORD; (* Axis control loop index (0, 1, 2, when multiple control
loops are used) *)
    ModuloActTurns                : DINT; (* Actual modulo turns *)
    ActVelo                       : LREAL; (* Actual velocity *)
    PosDiff                       : LREAL; (* Position difference (lag distance) *)
    SetPos                        : LREAL; (* Setpoint position *)
    SetVelo                       : LREAL; (* Setpoint velocity *)
    SetAcc                        : LREAL; (* Setpoint acceleration *)
    TargetPos                     : LREAL; (* Estimated target position *)
    ModuloSetPos                  : LREAL; (* Setpoint modulo position *)
    ModuloSetTurns                : DINT; (* Setpoint modulo turns *)
    CmdNo                         : WORD; (* Continuous actual command number *)
    CmdState                      : WORD; (* Command state *)
    SetJerk                       : LREAL;
    SetTorque                     : LREAL;
    ActTorque                     : LREAL;
    StateDWord2                   : NCTOPLC_AXIS_REF_STATE2;
    StateDWord3                   : DWORD;
    TouchProbeState               : DWORD;
    TouchProbeCounter             : DWORD;
    CamCouplingState              : ARRAY [0..7] OF NCTOPLC_AXIS_REF_CAMCOUPLINGSTATE;
    CamCouplingTableID            : ARRAY [0..7] OF UINT;
    ActTorqueDerivative           : LREAL;
    SetTorqueDerivative           : LREAL;
    AbsPhasingPos                 : LREAL;
    TorqueOffset                  : LREAL;
    ActPosWithoutPosCorrection    : LREAL;
    ActAcc                        : LREAL;
    DcTimeStamp                   : UDINT;
    {attribute 'hide'}
    _reserved2                    : ARRAY [1..4] OF USINT;
    UserData                      : LREAL;
END_STRUCT
END_TYPE

TYPE PLCTONC_AXIS_REF :
STRUCT
    ControlDWord        : PLCTONC_AXIS_REF_CTRL; (* Control double word *)
    Override            : UDINT; (* Velocity override *)
    AxisModeRequest     : UDINT; (* Axis operating mode (PLC request) *)
    AxisModeDWord       : UDINT; (* optional mode parameter *)
    AxisModeLReal       : LREAL; (* optional mode parameter *)
    PositionCorrection  : LREAL; (* Correction value for current position *)
    ExtSetPos           : LREAL; (* external position setpoint *)
    ExtSetVelo          : LREAL; (* external velocity setpoint *)
    ExtSetAcc           : LREAL; (* external acceleration setpoint *)
    ExtSetDirection     : DINT; (* external direction setpoint *)
    {attribute 'hide'}
    _reserved1          : UDINT; (* reserved *)
    ExtControllerOutput : LREAL; (* external controller output *)
    GearRatio1          : LREAL; (* Gear ratio for dynamic multi master coupling modes *)
    GearRatio2          : LREAL; (* Gear ratio for dynamic multi master coupling modes *)
    GearRatio3          : LREAL; (* Gear ratio for dynamic multi master coupling modes *)
    GearRatio4          : LREAL; (* Gear ratio for dynamic multi master coupling modes *)
    MapState            : BOOL; (* reserved - internal use *)
    PlcCycleControl     : BYTE;
    PlcCycleCount       : BYTE;
    {attribute 'hide'}
    _reserved2          : ARRAY [1..5] OF USINT;
    ExtTorque           : LREAL;
    {attribute 'hide'}
    _reserved3          : ARRAY [1..8] OF USINT;
END_STRUCT
END_TYPE

TYPE ST_AxisStatus :
STRUCT
    UpdateTaskIndex          : BYTE;  (* Task-Index of the task that updated this data set *)
    UpdateCycleTime          : LREAL; (* task cycle time of the task which calls the status function
 *)
    CycleCounter             : UDINT; (* PLC cycle counter when this data set updated *)
    NcCycleCounter           : UDINT; (* NC cycle counter incremented after NC task updated NcToPlc
data structures *)
    MotionState              : MC_AxisStates; (* motion state in the PLCopen state diagram *)
    Error                    : BOOL;  (* axis error state *)
    ErrorId                  : UDINT; (* axis error code *)
    (* PLCopen motion control statemachine states: *)
    ErrorStop                : BOOL;
    Disabled                 : BOOL;
    Stopping                 : BOOL;
    StandStill               : BOOL;
    DiscreteMotion           : BOOL;
    ContinuousMotion         : BOOL; (* StateDWord bit 19 *)
    SynchronizedMotion       : BOOL;
    Homing                   : BOOL;
    (* additional status - (PLCopen definition)*)
    ConstantVelocity         : BOOL; (* StateDWord bit 12 *)
    Accelerating             : BOOL;
    Decelerating             : BOOL;
    (* Axis.NcToPlc.StateDWord *)
    Operational              : BOOL; (* StateDWord bit 0 *)
    ControlLoopClosed        : BOOL; (* StateDWord bit 20 -
 operational and position control active *)
    HasJob                   : BOOL; (* StateDWord bit 8 *)
    HasBeenStopped           : BOOL; (* StateDWord bit 7 *)
    NewTargetPosition        : BOOL; (* StateDWord bit 17 *-
* new target position commanded during move *)
    InPositionArea           : BOOL; (* StateDWord bit 3 *)
    InTargetPosition         : BOOL; (* StateDWord bit 4 *)
    ProtectedMode            : BOOL; (* StateDWord bit 5 *)
    Homed                    : BOOL; (* StateDWord bit 1 *)
    HomingBusy               : BOOL; (* StateDWord bit 11 *)
    MotionCommandsLocked     : BOOL; (* StateDWord bit 29 *-* stop 'n hold *)
    SoftLimitMinExceeded     : BOOL; (* StateDWord bit 26 *-* reverse soft travel limit exceeded *)
    SoftLimitMaxExceeded     : BOOL; (* StateDWord bit 27 *-* forward soft travel limit exceeded *)
    Moving                   : BOOL; (* StateDWord bit 9 or 10 *)
    PositiveDirection        : BOOL; (* StateDWord bit 9 *)
    NegativeDirection        : BOOL; (* StateDWord bit 10 *)
    NotMoving                : BOOL; (* StateDWord bit 2 *)
    Compensating             : BOOL; (* StateDWord bit 13 *-* superposition - overlayed motion *)
    ExtSetPointGenEnabled    : BOOL; (* StateDWord bit 14 *)
    PhasingActive            : BOOL; (* StateDWord bit 15 *)
    ExternalLatchValid       : BOOL; (* StateDWord bit 16 *)
    CamDataQueued            : BOOL; (* StateDWord bit 22 *)
    CamTableQueued           : BOOL; (* StateDWord bit 21 *)
    CamScalingPending        : BOOL; (* StateDWord bit 23 *)
    CmdBuffered              : BOOL; (* StateDWord bit 24 *)
    PTPmode                  : BOOL; (* StateDWord bit 25 *)
    DriveDeviceError         : BOOL; (* StateDWord bit 28 *)
    IoDataInvalid            : BOOL; (* StateDWord bit 30 *)
    ErrorPropagationDelayed  : BOOL; (* StateDWord bit 6 *)
    DriveLimitActive         : BOOL; (* StateDWord bit 18 *)
    (* Axis.NcToPlc.CoupleState *)
    Coupled                  : BOOL;
    (* axis operation mode feedback from NcToPlc *)
    OpMode                   : ST_AxisOpModes;
    NcApplicationRequest     : BOOL; (* OpModeDWord bit 23 *)
END_STRUCT
END_TYPE

TYPE ST_AdsAddress :
STRUCT
    NetId   : STRING(23);
    Port    : UINT;
    Channel : UINT;
END_STRUCT
END_TYPE

TYPE ST_DriveAddress :
STRUCT
    NetID               : T_AmsNetId;     (* AMS NetID of the drive as a string *)
    NetIdBytes          : T_AmsNetIdArr;  (* AMS NetID of the drive as a byte array (same informatio
n as NetID) *)
    SlaveAddress        : T_AmsPort;      (* slave address of the drive connected to a bus master *)
    Channel             : BYTE;           (* channel number of the drive *)
    (* new since 2013-04-04 - just available with versions after this date, otherwise zero *)
    NcDriveId           : DWORD;          (* ID [1..255] of the NC software drive of an axis *)
    NcDriveIndex        : DWORD;          (* index [0..9] of the NC software drive of an axis *)
    NcDriveType         : E_NcDriveType;  (* type enumeration of the NC software drive of an axis *)
    NcEncoderId         : DWORD;          (* ID [1..255] of the NC software encoder of an axis *)
    NcEncoderIndex      : DWORD;          (* index [0..9] of the NC software encoder of an axis *)
    NcEncoderType       : E_NcEncoderType;(* type enumeration of the NC encoder drive of an axis *)
    NcAxisId            : DWORD;          (* ID [1..255] of the NC axis *)
    NcAxisType          : E_NcAxisType;   (* type enumeration of the NC axis *)
    (* new since 2016-04-11 - just available with versions after this date, otherwise zero *)
    TcDriveObjectId     : DWORD;
    TcEncoderObjectId   : DWORD;
    TcAxisObjectId      : DWORD;
END_STRUCT
END_TYPE

TYPE MC_Direction :
(
    MC_Positive_Direction := 1,
    MC_Shortest_Way ,
    MC_Negative_Direction,
    MC_Current_Direction,
    MC_Undefined_Direction := 128
);
END_TYPE

TYPE MC_BufferMode :
 (
    MC_Aborting,
    MC_Buffered,
    MC_BlendingLow,
    MC_BlendingPrevious,
    MC_BlendingNext,
    MC_BlendingHigh
 );
END_TYPE

TYPE ST_MoveOptions :
STRUCT
// Command activation at defined ActivationPosition
// Extends the buffer mode when enabled
     EnableBlendingPosition : BOOL;
     BlendingPosition : LREAL;

// PositionAreaMonitoring, TargetPositionMonitoring
// and StopMonitoring can be ignored using this flag
     IgnorePositionMonitoring : BOOL;
// PositionAreaMonitoring, TargetPositionMonitoring
// can be enabled for MC_Stop and MC_Halt commands
     EnableStopPositionMonitoring : BOOL;
END_STRUCT
END_TYPE

TYPE ST_HomingOptions :
STRUCT
    ClearPositionLag : BOOL;
    SearchDirection  : MC_Direction := MC_Direction.MC_Undefined_Direction;
    SearchVelocity   : LREAL;
    SyncDirection    : MC_Direction := MC_Direction.MC_Undefined_Direction;
    SyncVelocity     : LREAL;
    ReferenceMode    : E_EncoderReferenceMode :=
E_EncoderReferenceMode.ENCODERREFERENCEMODE_DEFAULT;
END_STRUCT
END_TYPE

TYPE ST_SetPositionOptions :
STRUCT
    ClearPositionLag    : BOOL;
    SelectEncoderIndex  : BOOL;
    EncoderIndex        : UINT;
    ClearPositionOffset : BOOL;
END_STRUCT
END_TYPE

TYPE MC_HomingMode :
(
    MC_DefaultHoming,    (* default homing as defined in the SystemManager encoder parameters *)
    MC_Direct,           (* Static Homing forcing position from user reference *)
    MC_ForceCalibration, (* set the calibration flag without performing any motion or changing the p
osition *)
    MC_ResetCalibration  (* resets the calibration flag without performing any motion or changing th
e position *)
);
END_TYPE

TYPE E_JogMode :
(
    MC_JOGMODE_STANDARD_SLOW, (* motion with standard jog parameters for slow motion *)
    MC_JOGMODE_STANDARD_FAST, (* motion with standard jog parameters for fast motion *)
    MC_JOGMODE_CONTINOUS, (* axis moves as long as the jog button is pressed using parameterized dyn
amics *)
    MC_JOGMODE_INCHING, (* axis moves for a certain relative distance *)
    MC_JOGMODE_INCHING_MODULO (* axis moves for a certain relative distance -
 stop position is rounded to the distance value *)
);
END_TYPE

TYPE MC_AxisStates :
(
    MC_AXISSTATE_UNDEFINED,
    MC_AXISSTATE_DISABLED,
    MC_AXISSTATE_STANDSTILL,
    MC_AXISSTATE_ERRORSTOP,
    MC_AXISSTATE_STOPPING,
    MC_AXISSTATE_HOMING,
    MC_AXISSTATE_DISCRETEMOTION,
    MC_AXISSTATE_CONTINOUSMOTION,
    MC_AXISSTATE_SYNCHRONIZEDMOTION
);
END_TYPE

TYPE NCTOPLC_AXIS_REF_STATE :
    DWORD;
END_TYPE

TYPE NCTOPLC_AXIS_REF_STATE2 :
UNION
    Value     : DWORD;
    Flags     : NCTOPLC_AXIS_REF_STATE2_FLAGS;
END_UNION
END_TYPE

TYPE NCTOPLC_AXIS_REF_CAMCOUPLINGSTATE :
STRUCT
    CamActivationPending    : BIT;
    CamDeactivationPending  : BIT;
    CamActive               : BIT;
    {attribute 'hide'}
    _reserved1              : BIT;
    {attribute 'hide'}
    _reserved2              : BIT;
    {attribute 'hide'}
    _reserved3              : BIT;
    CamDataQueued           : BIT;
    CamScalingPending       : BIT;
END_STRUCT
END_TYPE

TYPE PLCTONC_AXIS_REF_CTRL :
    DWORD;
END_TYPE

TYPE ST_AxisOpModes :
STRUCT
    PositionAreaMonitoring   : BOOL; (* bit 0 - OpModeDWord *)
    TargetPositionMonitoring : BOOL; (* bit 1 - OpModeDWord *)
    LoopMode                 : BOOL; (* bit 2 - OpModeDWord - loop mode for two speed axes *)
    MotionMonitoring         : BOOL; (* bit 3 - OpModeDWord *)
    PEHTimeMonitoring        : BOOL; (* bit 4 - OpModeDWord *)
    BacklashCompensation     : BOOL; (* bit 5 - OpModeDWord *)
    DelayedErrorReaction     : BOOL; (* bit 6 - OpModeDWord *)
    Modulo                   : BOOL; (* bit 7 - OpModeDWord -
 axis is parameterized as modulo axis *)
    SimulationAxis           : BOOL; (* bit 8 - OpModeDWord *)
    PositionLagMonitoring    : BOOL; (* bit 16 - OpModeDWord *)
    VelocityLagMonitoring    : BOOL; (* bit 17 - OpModeDWord *)
    SoftLimitMinMonitoring   : BOOL; (* bit 18 - OpModeDWord *)
    SoftLimitMaxMonitoring   : BOOL; (* bit 19 - OpModeDWord *)
    PositionCorrection       : BOOL; (* bit 20 - OpModeDWord *)
    AllowSlaveCommands       : BOOL; (* bit 21 - OpModeDWord *)
    AllowExtSetAxisCommands  : BOOL; (* bit 22 - OpModeDWord *)
END_STRUCT
END_TYPE

TYPE E_NcDriveType :
(
    NcDriveType_undefined            := 0,
    NcDriveType_M2400_DAC1           := 1,
    NcDriveType_M2400_DAC2           := 2,
    NcDriveType_M2400_DAC3           := 3,
    NcDriveType_M2400_DAC4           := 4,
    NcDriveType_KL4xxx               := 5,
    NcDriveType_KL4xxx_NonLinear     := 6,
    NcDriveType_Discete_TwoSpeed     := 7,
    NcDriveType_Stepper              := 8,
    NcDriveType_Sercos               := 9,
    NcDriveType_KL5051               := 10,
    NcDriveType_AX2000_B200          := 11,
    NcDriveType_ProfilDrive          := 12,
    NcDriveType_Universal            := 13,
    NcDriveType_NcBackplane          := 14,
    NcDriveType_CANopen_Lenze        := 15,
    NcDriveType_CANopen_DS402_MDP742 := 16,
    NcDriveType_AX2000_B900          := 17,
    NcDriveType_KL2531_Stepper       := 20,
    NcDriveType_KL2532_DC            := 21,
    NcDriveType_TCOM                 := 22,
    NcDriveType_MDP_733              := 23,
    NcDriveType_MDP_703              := 24
)DWORD;
END_TYPE

TYPE E_NcEncoderType :
(
    NcEncoderType_undefined,
    NcEncoderType_Simulation,
    NcEncoderType_ABS_M3000,
    NcEncoderType_INC_M31X0,
    NcEncoderType_INC_KL5101,
    NcEncoderType_ABS_KL5001_SSI,
    NcEncoderType_INC_KL5051,
    NcEncoderType_ABS_KL30XX,
    NcEncoderType_INC_Sercos_P,
    NcEncoderType_INC_Sercos_PV,
    NcEncoderType_INC_Binary,
    NcEncoderType_ABS_M2510,
    NcEncoderType_ABS_FOX50,
    NcEncoderType_HYDRAULIC_FORCE,
    NcEncoderType_AX2000_B200,
    NcEncoderType_PROFIDRIVE,
    NcEncoderType_UNIVERSAL,
    NcEncoderType_NCBACKPLANE,
    NcEncoderType_CANOPEN_LENZE,
    NcEncoderType_CANOPEN_DS402_MDP513_MDP742,
    NcEncoderType_AX2000_B900,
    NcEncoderType_KL5151,
    NcEncoderType_IP5209,
    NcEncoderType_KL2531_Stepper,
    NcEncoderType_KL2532_DC,
    NcEncoderType_TIMEBASEGENERATOR,
    NcEncoderType_INC_TCOM,
    NcEncoderType_CANOPEN_MDP513_64BIT,
    NcEncoderType_SPECIFIC
)DWORD;
END_TYPE

TYPE E_NcAxisType :
(
    NcAxisType_undefined            := 0,
    NcAxisType_Continious           := 1,
    NcAxisType_Discrete_TwoSpeed    := 2,
    NcAxisType_LowCostStepper_DigIO := 3,
    NcAxisType_Encoder              := 5,
    NcAxisType_Hydraulic            := 6,
    NcAxisType_TimeGenerator        := 7,
    NcAxisType_Specific             := 100
)DWORD;
END_TYPE

TYPE NCTOPLC_AXIS_REF_STATE2_FLAGS :
STRUCT
    AvoidingCollision       : BIT;
    {attribute 'hide'}
    _reserved1              : BIT;
    {attribute 'hide'}
    _reserved2              : BIT;
    {attribute 'hide'}
    _reserved3              : BIT;
    {attribute 'hide'}
    _reserved4              : BIT;
    {attribute 'hide'}
    _reserved5              : BIT;
    {attribute 'hide'}
    _reserved6              : BIT;
    {attribute 'hide'}
    _reserved7              : BIT;
    {attribute 'hide'}
    _reserved8              : ARRAY [1..3] OF USINT;
END_STRUCT
END_TYPE

TYPE NCTOPLC_AXIS_REF_OPMODE :
    DWORD;
END_TYPE

TYPE E_EncoderReferenceMode :
(
    ENCODERREFERENCEMODE_DEFAULT           :=  0,
    ENCODERREFERENCEMODE_PLCCAM            :=  1,
    ENCODERREFERENCEMODE_HARDWARESYNC      :=  2,
    ENCODERREFERENCEMODE_HARDWARELATCHPOS  :=  3,
    ENCODERREFERENCEMODE_HARDWARELATCHNEG  :=  4,
    ENCODERREFERENCEMODE_SOFTWARESYNC      :=  5,
    ENCODERREFERENCEMODE_SOFTDRIVELATCHPOS :=  6,
    ENCODERREFERENCEMODE_SOFTDRIVELATCHNEG :=  7
)UDINT;
END_TYPE

(* ST_PowerOptions: "not implemented" in Tc2_MC2; no members are published. *)
TYPE ST_PowerOptions :
STRUCT
END_STRUCT
END_TYPE

FUNCTION_BLOCK MC_Power
VAR_INPUT
    Enable          : BOOL;
    Enable_Positive : BOOL;
    Enable_Negative : BOOL;
    Override        : LREAL := 100.0;
    BufferMode      : MC_BufferMode;
    Options         : ST_PowerOptions;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Status  : BOOL;
    Busy    : BOOL;
    Active  : BOOL;
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
END_FUNCTION_BLOCK

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
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_Stop
VAR_INPUT
    Execute      : BOOL;
    Deceleration : LREAL;
    Jerk         : LREAL;
    Options      : ST_MoveOptions;
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
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_Halt
VAR_INPUT
    Execute      : BOOL;
    Deceleration : LREAL;
    Jerk         : LREAL;
    BufferMode   : MC_BufferMode;
    Options      : ST_MoveOptions;
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
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_Home
VAR_INPUT
    Execute         : BOOL;
    Position        : LREAL := DEFAULT_HOME_POSITION;
    HomingMode      : MC_HomingMode;
    BufferMode      : MC_BufferMode;
    Options         : ST_HomingOptions;
    bCalibrationCam : BOOL;
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
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_MoveAbsolute
VAR_INPUT
    Execute      : BOOL;
    Position     : LREAL;
    Velocity     : LREAL;
    Acceleration : LREAL;
    Deceleration : LREAL;
    Jerk         : LREAL;
    BufferMode   : MC_BufferMode;
    Options      : ST_MoveOptions;
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
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_MoveRelative
VAR_INPUT
    Execute      : BOOL;
    Distance     : LREAL;
    Velocity     : LREAL;
    Acceleration : LREAL;
    Deceleration : LREAL;
    Jerk         : LREAL;
    BufferMode   : MC_BufferMode;
    Options      : ST_MoveOptions;
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
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_MoveVelocity
VAR_INPUT
    Execute      : BOOL;
    Velocity     : LREAL;
    Acceleration : LREAL;
    Deceleration : LREAL;
    Jerk         : LREAL;
    Direction    : MC_Direction := MC_Direction#MC_Positive_Direction;
    BufferMode   : MC_BufferMode;
    Options      : ST_MoveOptions;
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
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_SetPosition
VAR_INPUT
    Execute  : BOOL;
    Position : LREAL;
    Mode     : BOOL;
    Options  : ST_SetPositionOptions;
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
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_ReadActualPosition
VAR_INPUT
    Enable : BOOL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Valid    : BOOL;
    Busy     : BOOL;
    Error    : BOOL;
    ErrorID  : UDINT;
    Position : LREAL;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_ReadStatus
VAR_INPUT
    Enable : BOOL;
END_VAR
VAR_IN_OUT
    Axis : AXIS_REF;
END_VAR
VAR_OUTPUT
    Valid              : BOOL;
    Busy               : BOOL;
    Error              : BOOL;
    ErrorId            : UDINT;
    ErrorStop          : BOOL;
    Disabled           : BOOL;
    Stopping           : BOOL;
    StandStill         : BOOL;
    DiscreteMotion     : BOOL;
    ContinuousMotion   : BOOL;
    SynchronizedMotion : BOOL;
    Homing             : BOOL;
    ConstantVelocity   : BOOL;
    Accelerating       : BOOL;
    Decelerating       : BOOL;
    Status             : ST_AxisStatus;
END_VAR
END_FUNCTION_BLOCK

(* Gearing options: ST_GearOutOptions is "currently not implemented" and the
   slave type of ST_GearInOptions "not used"; its enumeration is not
   published, so RootPLC declares it as a DINT. *)
TYPE
    ST_GearInOptions : STRUCT
        SlaveType : DINT;
    END_STRUCT;
    ST_GearOutOptions : STRUCT
    END_STRUCT;
END_TYPE

FUNCTION_BLOCK MC_Jog
VAR_INPUT
    JogForward   : BOOL;
    JogBackwards : BOOL;
    Mode         : E_JogMode;
    Position     : LREAL;
    Velocity     : LREAL;
    Acceleration : LREAL;
    Deceleration : LREAL;
    Jerk         : LREAL;
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
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_GearIn
VAR_INPUT
    Execute          : BOOL;
    RatioNumerator   : LREAL;
    RatioDenominator : UINT;
    Acceleration     : LREAL;
    Deceleration     : LREAL;
    Jerk             : LREAL;
    BufferMode       : MC_BufferMode;
    Options          : ST_GearInOptions;
END_VAR
VAR_IN_OUT
    Master : AXIS_REF;
    Slave  : AXIS_REF;
END_VAR
VAR_OUTPUT
    InGear         : BOOL;
    Busy           : BOOL;
    Active         : BOOL;
    CommandAborted : BOOL;
    Error          : BOOL;
    ErrorID        : UDINT;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK MC_GearOut
VAR_INPUT
    Execute : BOOL;
    Options : ST_GearOutOptions;
END_VAR
VAR_IN_OUT
    Slave : AXIS_REF;
END_VAR
VAR_OUTPUT
    Done    : BOOL;
    Busy    : BOOL;
    Error   : BOOL;
    ErrorID : UDINT;
END_VAR
END_FUNCTION_BLOCK
