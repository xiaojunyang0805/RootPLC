(* Tc2_System compatibility library for RootPLC (see library.toml for the
   public references and the non-affiliation note).

   Where the vendor documentation does not state the type of a constant, the
   type here is the one its use implies: ADSLOG message types combine into
   the DWORD msgCtrlMask, ADS states and AMS ports are UINT. *)

VAR_GLOBAL CONSTANT
    MAX_STRING_LENGTH : UDINT := 255;
    PI : LREAL := 3.1415926535897932384626433832795;
    DEFAULT_ADS_TIMEOUT : TIME := T#5s;

    ADSLOG_MSGTYPE_HINT : DWORD := 16#01;
    ADSLOG_MSGTYPE_WARN : DWORD := 16#02;
    ADSLOG_MSGTYPE_ERROR : DWORD := 16#04;
    ADSLOG_MSGTYPE_LOG : DWORD := 16#10;
    ADSLOG_MSGTYPE_MSGBOX : DWORD := 16#20;
    ADSLOG_MSGTYPE_RESOURCE : DWORD := 16#40;
    ADSLOG_MSGTYPE_STRING : DWORD := 16#80;

    ADSSTATE_INVALID : UINT := 0;
    ADSSTATE_IDLE : UINT := 1;
    ADSSTATE_RESET : UINT := 2;
    ADSSTATE_INIT : UINT := 3;
    ADSSTATE_START : UINT := 4;
    ADSSTATE_RUN : UINT := 5;
    ADSSTATE_STOP : UINT := 6;
    ADSSTATE_SAVECFG : UINT := 7;
    ADSSTATE_LOADCFG : UINT := 8;
    ADSSTATE_POWERFAILURE : UINT := 9;
    ADSSTATE_POWERGOOD : UINT := 10;
    ADSSTATE_ERROR : UINT := 11;
    ADSSTATE_SHUTDOWN : UINT := 12;
    ADSSTATE_SUSPEND : UINT := 13;
    ADSSTATE_RESUME : UINT := 14;
    ADSSTATE_CONFIG : UINT := 15;
    ADSSTATE_RECONFIG : UINT := 16;
    ADSSTATE_STOPPING : UINT := 17;
    ADSSTATE_INCOMPATIBLE : UINT := 18;
    ADSSTATE_EXCEPTION : UINT := 19;
    ADSSTATE_MAXSTATES : UINT := 20;

    AMSPORT_LOGGER : UINT := 100;
    AMSPORT_EVENTLOG : UINT := 110;
    AMSPORT_R0_RTIME : UINT := 200;
    AMSPORT_R0_IO : UINT := 300;
    AMSPORT_R0_NC : UINT := 500;
    AMSPORT_R0_PLC : UINT := 800;
    AMSPORT_R0_PLC_RTS1 : UINT := 801;
    AMSPORT_R0_PLC_RTS2 : UINT := 811;
    AMSPORT_R0_PLC_RTS3 : UINT := 821;
    AMSPORT_R0_PLC_RTS4 : UINT := 831;
    AMSPORT_R3_SYSSERV : UINT := 10000;
END_VAR

TYPE
    T_MaxString : STRING[MAX_STRING_LENGTH];
END_TYPE

(* Writes a message to the event log and/or a message box. Declared only:
   RootPLC type-checks calls but does not run them (no event log). *)
FUNCTION ADSLOGSTR : DINT
VAR_INPUT
    msgCtrlMask : DWORD;
    msgFmtStr : T_MaxString;
    strArg : T_MaxString;
END_VAR
END_FUNCTION

FUNCTION ADSLOGDINT : DINT
VAR_INPUT
    msgCtrlMask : DWORD;
    msgFmtStr : T_MaxString;
    dintArg : DINT;
END_VAR
END_FUNCTION

FUNCTION ADSLOGLREAL : DINT
VAR_INPUT
    msgCtrlMask : DWORD;
    msgFmtStr : T_MaxString;
    lrealArg : LREAL;
END_VAR
END_FUNCTION

(* Library versions: every TwinCAT library has a constant of this type
   (stLibVersion_<name>); F_CmpLibVersion returns -1, 0 or +1 as the given
   version is lower than, equal to or higher than the required one. *)
TYPE
    ST_LibVersion : STRUCT
        iMajor : UINT;
        iMinor : UINT;
        iBuild : UINT;
        iRevision : UINT;
        nFlags : DWORD;
        sVersion : STRING[23];
    END_STRUCT;
END_TYPE

FUNCTION F_CmpLibVersion : DINT
VAR_INPUT
    stVersion : ST_LibVersion;
    iMajor : UINT;
    iMinor : UINT;
    iBuild : UINT;
    iRevision : UINT;
END_VAR
VAR
    have : ARRAY[0..3] OF UINT;
    want : ARRAY[0..3] OF UINT;
    i : INT;
END_VAR
have[0] := stVersion.iMajor;
have[1] := stVersion.iMinor;
have[2] := stVersion.iBuild;
have[3] := stVersion.iRevision;
want[0] := iMajor;
want[1] := iMinor;
want[2] := iBuild;
want[3] := iRevision;
F_CmpLibVersion := 0;
FOR i := 0 TO 3 DO
    IF have[i] < want[i] THEN
        F_CmpLibVersion := -1;
        RETURN;
    ELSIF have[i] > want[i] THEN
        F_CmpLibVersion := 1;
        RETURN;
    END_IF
END_FOR
END_FUNCTION

(* AMS addressing *)
TYPE
    T_AmsNetId : STRING[23];
    T_AmsNetIdArr : ARRAY[0..5] OF BYTE;
    T_AmsPort : UINT;
    ST_AmsAddr : STRUCT
        netId : T_AmsNetIdArr;
        port : T_AmsPort;
    END_STRUCT;
END_TYPE

(* Task index: RootPLC runs one cyclic task, index 1. *)
FUNCTION_BLOCK GETCURTASKINDEX
VAR_OUTPUT
    index : BYTE;
END_VAR
index := 1;
END_FUNCTION_BLOCK

FUNCTION GETCURTASKINDEXEX : DINT
GETCURTASKINDEXEX := 1;
END_FUNCTION

(* CPU cycle counter in 100 ns units, low and high double word. *)
FUNCTION_BLOCK GETCPUCOUNTER
VAR_OUTPUT
    cpuCntLoDW : UDINT;
    cpuCntHiDW : UDINT;
END_VAR
END_FUNCTION_BLOCK
