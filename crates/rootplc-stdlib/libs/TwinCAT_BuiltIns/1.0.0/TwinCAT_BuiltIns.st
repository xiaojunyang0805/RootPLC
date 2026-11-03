(* TwinCAT_BuiltIns compatibility library for RootPLC (see library.toml).

   BIT: a single bit, used as a structure member; RootPLC treats it as BOOL
   (the packing of BIT members into bytes only matters for memory layout).
   IQueryInterface: the base interface TwinCAT code writes as
   __SYSTEM.IQueryInterface; it declares no methods. TYPE_CLASS: see below. *)

TYPE
    BIT : BOOL;
    (* special data types, 64-bit target (RootPLC's TwinCAT layout) *)
    XINT : LINT;
    UXINT : ULINT;
    XWORD : LWORD;
    PVOID : ULINT;
    __XINT : LINT;
    __UXINT : ULINT;
    __XWORD : LWORD;
END_TYPE

NAMESPACE __SYSTEM
INTERFACE IQueryInterface
END_INTERFACE

(* TYPE_CLASS: the type class of a value, as the CODESYS documentation of
   __SYSTEM.TYPE_CLASS gives it (TwinCAT is CODESYS based). *)
TYPE
    TYPE_CLASS : DWORD (
        TYPE_BOOL := 0,
        TYPE_BIT := 1,
        TYPE_BYTE := 2,
        TYPE_WORD := 3,
        TYPE_DWORD := 4,
        TYPE_LWORD := 5,
        TYPE_SINT := 6,
        TYPE_INT := 7,
        TYPE_DINT := 8,
        TYPE_LINT := 9,
        TYPE_USINT := 10,
        TYPE_UINT := 11,
        TYPE_UDINT := 12,
        TYPE_ULINT := 13,
        TYPE_REAL := 14,
        TYPE_LREAL := 15,
        TYPE_STRING := 16,
        TYPE_WSTRING := 17,
        TYPE_TIME := 18,
        TYPE_DATE := 19,
        TYPE_DATEANDTIME := 20,
        TYPE_TIMEOFDAY := 21,
        TYPE_POINTER := 22,
        TYPE_REFERENCE := 23,
        TYPE_SUBRANGE := 24,
        TYPE_ENUM := 25,
        TYPE_ARRAY := 26,
        TYPE_PARAMS := 27,
        TYPE_USERDEF := 28,
        TYPE_NONE := 29,
        TYPE_ANY := 30,
        TYPE_ANYBIT := 31,
        TYPE_ANYDATE := 32,
        TYPE_ANYINT := 33,
        TYPE_ANYNUM := 34,
        TYPE_ANYREAL := 35,
        TYPE_LAZY := 36,
        TYPE_LTIME := 37,
        TYPE_BITCONST := 38
    );
END_TYPE
END_NAMESPACE

(* System information (namespace TwinCAT_SystemInfoVarList): _TaskInfo per
   task and _AppInfo for the application. RootPLC runs one task, index 1
   (see GETCURTASKINDEXEX in Tc2_System); it declares these variables but
   does not fill them at run time, so they keep their initial values.
   EPlcPersistentStatus and ITComObjectServer are not published: the two
   members that use them are declared INT and PVOID. *)
TYPE
    OTCID : UDINT;
    PlcTaskSystemInfo : STRUCT
        ObjId : OTCID;
        CycleTime : UDINT;
        Priority : UINT;
        AdsPort : UINT;
        CycleCount : UDINT;
        DcTaskTime : LINT;
        LastExecTime : UDINT;
        FirstCycle : BOOL;
        CycleTimeExceeded : BOOL;
        InCallAfterOutputUpdate : BOOL;
        RTViolation : BOOL;
        TaskName : STRING[63];
    END_STRUCT;
    PlcAppSystemInfo : STRUCT
        ObjId : OTCID;
        TaskCnt : UDINT;
        OnlineChangeCnt : UDINT;
        Flags : DWORD;
        AdsPort : UINT;
        BootDataLoaded : BOOL;
        OldBootData : BOOL;
        AppTimestamp : DT;
        KeepOutputsOnBP : BOOL;
        ShutdownInProgress : BOOL;
        LicensesPending : BOOL;
        BSODOccured : BOOL;
        LoggedIn : BOOL;
        PersistentStatus : INT;
        TComSrvPtr : PVOID;
        AppName : STRING[63];
        ProjectName : STRING[63];
        ActivePlcForces : BOOL;
        ActiveIoForces : BOOL;
    END_STRUCT;
END_TYPE

NAMESPACE TwinCAT_SystemInfoVarList
VAR_GLOBAL
    _TaskInfo : ARRAY[1..1] OF PlcTaskSystemInfo;
    _AppInfo : PlcAppSystemInfo;
END_VAR
END_NAMESPACE
