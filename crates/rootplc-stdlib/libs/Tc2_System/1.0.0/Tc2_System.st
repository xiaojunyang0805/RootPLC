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

(* Writes a message to the event log and/or a message box. RootPLC has no
   event log: the message is recorded and `rootplc run` reports it
   ([stdlib.compat.log]). The first placeholder (%s, %d, %f) takes the
   argument. *)
FUNCTION ADSLOGSTR : DINT
VAR_INPUT
    msgCtrlMask : DWORD;
    msgFmtStr : T_MaxString;
    strArg : T_MaxString;
END_VAR
VAR
    at : INT;
    msg : T_MaxString;
END_VAR
msg := msgFmtStr;
at := FIND(msg, '%s');
IF at > 0 THEN
    msg := REPLACE(msg, strArg, 2, at);
END_IF;
__ROOTPLC_LOG(msgCtrlMask, msg);
ADSLOGSTR := 0;
END_FUNCTION

FUNCTION ADSLOGDINT : DINT
VAR_INPUT
    msgCtrlMask : DWORD;
    msgFmtStr : T_MaxString;
    dintArg : DINT;
END_VAR
VAR
    at : INT;
    msg : T_MaxString;
END_VAR
msg := msgFmtStr;
at := FIND(msg, '%d');
IF at > 0 THEN
    msg := REPLACE(msg, DINT_TO_STRING(dintArg), 2, at);
END_IF;
__ROOTPLC_LOG(msgCtrlMask, msg);
ADSLOGDINT := 0;
END_FUNCTION

FUNCTION ADSLOGLREAL : DINT
VAR_INPUT
    msgCtrlMask : DWORD;
    msgFmtStr : T_MaxString;
    lrealArg : LREAL;
END_VAR
VAR
    at : INT;
    msg : T_MaxString;
END_VAR
msg := msgFmtStr;
at := FIND(msg, '%f');
IF at > 0 THEN
    msg := REPLACE(msg, LREAL_TO_STRING(lrealArg), 2, at);
END_IF;
__ROOTPLC_LOG(msgCtrlMask, msg);
ADSLOGLREAL := 0;
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

(* Memory functions on addresses (ADR(x)). Declared only: RootPLC models
   addresses as typed references, so running one stops with UNSUPPORTED. *)
FUNCTION MEMCPY : UDINT
VAR_INPUT
    destAddr : PVOID;
    srcAddr : PVOID;
    n : UDINT;
END_VAR
END_FUNCTION

FUNCTION MEMMOVE : UDINT
VAR_INPUT
    destAddr : PVOID;
    srcAddr : PVOID;
    n : UDINT;
END_VAR
END_FUNCTION

FUNCTION MEMSET : UDINT
VAR_INPUT
    destAddr : PVOID;
    fillByte : USINT;
    n : UDINT;
END_VAR
END_FUNCTION

FUNCTION MEMCMP : DINT
VAR_INPUT
    pBuf1 : PVOID;
    pBuf2 : PVOID;
    n : UDINT;
END_VAR
END_FUNCTION

(* Pseudo-random LREAL in 0.0 .. 1.0, series given by Seed. The generator
   is not published: declared only. *)
FUNCTION_BLOCK DRAND
VAR_INPUT
    Seed : INT;
END_VAR
VAR_OUTPUT
    Num : LREAL;
END_VAR
END_FUNCTION_BLOCK

(* File access (TwinCAT system service) and ADS: declared only. *)
VAR_GLOBAL CONSTANT
    FOPEN_MODEREAD : DWORD := 16#0001;
    FOPEN_MODEWRITE : DWORD := 16#0002;
    FOPEN_MODEAPPEND : DWORD := 16#0004;
    FOPEN_MODEPLUS : DWORD := 16#0008;
    FOPEN_MODEBINARY : DWORD := 16#0010;
    FOPEN_MODETEXT : DWORD := 16#0020;
END_VAR

TYPE
    E_OpenPath : (
        PATH_GENERIC := 1,
        PATH_BOOTPRJ,
        PATH_BOOTDATA,
        PATH_BOOTPATH,
        PATH_USERPATH1 := 11,
        PATH_USERPATH2,
        PATH_USERPATH3,
        PATH_USERPATH4,
        PATH_USERPATH5,
        PATH_USERPATH6,
        PATH_USERPATH7,
        PATH_USERPATH8,
        PATH_USERPATH9
    );
END_TYPE

FUNCTION_BLOCK FB_FileOpen
VAR_INPUT
    sNetId : T_AmsNetId;
    sPathName : T_MaxString;
    nMode : DWORD;
    ePath : E_OpenPath := E_OpenPath#PATH_GENERIC;
    bExecute : BOOL;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bError : BOOL;
    nErrId : UDINT;
    hFile : UINT;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_FileClose
VAR_INPUT
    sNetId : T_AmsNetId;
    hFile : UINT;
    bExecute : BOOL;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bError : BOOL;
    nErrId : UDINT;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_FileWrite
VAR_INPUT
    sNetId : T_AmsNetId;
    hFile : UINT;
    pWriteBuff : PVOID;
    cbWriteLen : UDINT;
    bExecute : BOOL;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bError : BOOL;
    nErrId : UDINT;
    cbWrite : UDINT;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_FileRead
VAR_INPUT
    sNetId : T_AmsNetId;
    hFile : UINT;
    pReadBuff : PVOID;
    cbReadLen : UDINT;
    bExecute : BOOL;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bError : BOOL;
    nErrId : UDINT;
    cbRead : UDINT;
    bEOF : BOOL;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_FilePuts
VAR_INPUT
    sNetId : T_AmsNetId;
    hFile : UINT;
    sLine : T_MaxString;
    bExecute : BOOL;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bError : BOOL;
    nErrId : UDINT;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_FileGets
VAR_INPUT
    sNetId : T_AmsNetId;
    hFile : UINT;
    bExecute : BOOL;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bError : BOOL;
    nErrId : UDINT;
    sLine : T_MaxString;
    bEOF : BOOL;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_FileDelete
VAR_INPUT
    sNetId : T_AmsNetId;
    sPathName : T_MaxString;
    ePath : E_OpenPath := E_OpenPath#PATH_GENERIC;
    bExecute : BOOL;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bError : BOOL;
    nErrId : UDINT;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_CreateDir
VAR_INPUT
    sNetId : T_AmsNetId;
    sPathName : T_MaxString;
    ePath : E_OpenPath := E_OpenPath#PATH_GENERIC;
    bExecute : BOOL;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bError : BOOL;
    nErrId : UDINT;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK ADSREAD
VAR_INPUT
    NETID : T_AmsNetId;
    PORT : T_AmsPort;
    IDXGRP : UDINT;
    IDXOFFS : UDINT;
    LEN : UDINT;
    DESTADDR : PVOID;
    READ : BOOL;
    TMOUT : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    BUSY : BOOL;
    ERR : BOOL;
    ERRID : UDINT;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK ADSWRITE
VAR_INPUT
    NETID : T_AmsNetId;
    PORT : T_AmsPort;
    IDXGRP : UDINT;
    IDXOFFS : UDINT;
    LEN : UDINT;
    SRCADDR : PVOID;
    WRITE : BOOL;
    TMOUT : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    BUSY : BOOL;
    ERR : BOOL;
    ERRID : UDINT;
END_VAR
END_FUNCTION_BLOCK

(* Operating system timestamp: a file time, 100 ns units since 1601-01-01
   UTC. RootPLC returns the virtual time of day ([stdlib.compat.clock]). *)
FUNCTION F_GetSystemTime : ULINT
F_GetSystemTime := LINT_TO_ULINT(__ROOTPLC_CLOCK_NS() / 100) + ULINT#116444736000000000;
END_FUNCTION

(* '127.16.17.3.1.1' from the six bytes of an AMS NetID. *)
FUNCTION F_CreateAmsNetId : T_AmsNetId
VAR_INPUT
    nIds : T_AmsNetIdArr;
END_VAR
VAR
    i : INT;
    s : T_AmsNetId;
END_VAR
s := BYTE_TO_STRING(nIds[0]);
FOR i := 1 TO 5 DO
    s := CONCAT(CONCAT(s, '.'), BYTE_TO_STRING(nIds[i]));
END_FOR
F_CreateAmsNetId := s;
END_FUNCTION

(* ADS return codes as an enumeration (UDINT). Values and names from the
   public ADS return code table; the member names drop the ADSERR_ prefix
   (DEVICE_NOMEMORY for ADSERR_DEVICE_NOMEMORY), the spelling TwinCAT code
   uses. NOERR is ERR_NOERROR. The global ERR_ and router codes are left
   out: their member names are not published. *)
TYPE E_AdsErr :
(
    NOERR := 16#0,
    DEVICE_ERROR := 16#700,
    DEVICE_SRVNOTSUPP := 16#701,
    DEVICE_INVALIDGRP := 16#702,
    DEVICE_INVALIDOFFSET := 16#703,
    DEVICE_INVALIDACCESS := 16#704,
    DEVICE_INVALIDSIZE := 16#705,
    DEVICE_INVALIDDATA := 16#706,
    DEVICE_NOTREADY := 16#707,
    DEVICE_BUSY := 16#708,
    DEVICE_INVALIDCONTEXT := 16#709,
    DEVICE_NOMEMORY := 16#70A,
    DEVICE_INVALIDPARM := 16#70B,
    DEVICE_NOTFOUND := 16#70C,
    DEVICE_SYNTAX := 16#70D,
    DEVICE_INCOMPATIBLE := 16#70E,
    DEVICE_EXISTS := 16#70F,
    DEVICE_SYMBOLNOTFOUND := 16#710,
    DEVICE_SYMBOLVERSIONINVALID := 16#711,
    DEVICE_INVALIDSTATE := 16#712,
    DEVICE_TRANSMODENOTSUPP := 16#713,
    DEVICE_NOTIFYHNDINVALID := 16#714,
    DEVICE_CLIENTUNKNOWN := 16#715,
    DEVICE_NOMOREHDLS := 16#716,
    DEVICE_INVALIDWATCHSIZE := 16#717,
    DEVICE_NOTINIT := 16#718,
    DEVICE_TIMEOUT := 16#719,
    DEVICE_NOINTERFACE := 16#71A,
    DEVICE_INVALIDINTERFACE := 16#71B,
    DEVICE_INVALIDCLSID := 16#71C,
    DEVICE_INVALIDOBJID := 16#71D,
    DEVICE_PENDING := 16#71E,
    DEVICE_ABORTED := 16#71F,
    DEVICE_WARNING := 16#720,
    DEVICE_INVALIDARRAYIDX := 16#721,
    DEVICE_SYMBOLNOTACTIVE := 16#722,
    DEVICE_ACCESSDENIED := 16#723,
    DEVICE_LICENSENOTFOUND := 16#724,
    DEVICE_LICENSEEXPIRED := 16#725,
    DEVICE_LICENSEEXCEEDED := 16#726,
    DEVICE_LICENSEINVALID := 16#727,
    DEVICE_LICENSESYSTEMID := 16#728,
    DEVICE_LICENSENOTIMELIMIT := 16#729,
    DEVICE_LICENSEFUTUREISSUE := 16#72A,
    DEVICE_LICENSETIMETOLONG := 16#72B,
    DEVICE_EXCEPTION := 16#72C,
    DEVICE_LICENSEDUPLICATED := 16#72D,
    DEVICE_SIGNATUREINVALID := 16#72E,
    DEVICE_CERTIFICATEINVALID := 16#72F,
    DEVICE_LICENSEOEMNOTFOUND := 16#730,
    DEVICE_LICENSERESTRICTED := 16#731,
    DEVICE_LICENSEDEMODENIED := 16#732,
    DEVICE_INVALIDFNCID := 16#733,
    DEVICE_OUTOFRANGE := 16#734,
    DEVICE_INVALIDALIGNMENT := 16#735,
    DEVICE_LICENSEPLATFORM := 16#736,
    DEVICE_FORWARD_PL := 16#737,
    DEVICE_FORWARD_DL := 16#738,
    DEVICE_FORWARD_RT := 16#739,
    CLIENT_ERROR := 16#740,
    CLIENT_INVALIDPARM := 16#741,
    CLIENT_LISTEMPTY := 16#742,
    CLIENT_VARUSED := 16#743,
    CLIENT_DUPLINVOKEID := 16#744,
    CLIENT_SYNCTIMEOUT := 16#745,
    CLIENT_W32ERROR := 16#746,
    CLIENT_TIMEOUTINVALID := 16#747,
    CLIENT_PORTNOTOPEN := 16#748,
    CLIENT_NOAMSADDR := 16#749,
    CLIENT_SYNCINTERNAL := 16#750,
    CLIENT_ADDHASH := 16#751,
    CLIENT_REMOVEHASH := 16#752,
    CLIENT_NOMORESYM := 16#753,
    CLIENT_SYNCRESINVALID := 16#754,
    CLIENT_SYNCPORTLOCKED := 16#755,
    CLIENT_REQUESTCANCELLED := 16#756
) UDINT;
END_TYPE

(* ADS return codes in HRESULT form (16#9811_0000 + code), the enumeration
   Tc3 functions return errors with. Values from the public ADS return code
   table; members are the device codes without the ADSERR_DEVICE_ prefix
   (INVALIDPARM for ADSERR_DEVICE_INVALIDPARM), the spelling TwinCAT code
   and the TwinCAT Vision HRESULT table use. HRESULT_ADS_NOERROR is taken to
   be 0 (S_OK): code uses it as the success case, but its value is not
   published. Other ranges are left out (names not published). The values
   are negative as DINT (HRESULT). *)
TYPE E_HRESULTAdsErr :
(
    HRESULT_ADS_NOERROR := 0,
    ERROR := -1743714560,
    SRVNOTSUPP := -1743714559,
    INVALIDGRP := -1743714558,
    INVALIDOFFSET := -1743714557,
    INVALIDACCESS := -1743714556,
    INVALIDSIZE := -1743714555,
    INVALIDDATA := -1743714554,
    NOTREADY := -1743714553,
    BUSY := -1743714552,
    INVALIDCONTEXT := -1743714551,
    NOMEMORY := -1743714550,
    INVALIDPARM := -1743714549,
    NOTFOUND := -1743714548,
    SYNTAX := -1743714547,
    INCOMPATIBLE := -1743714546,
    EXISTS := -1743714545,
    SYMBOLNOTFOUND := -1743714544,
    SYMBOLVERSIONINVALID := -1743714543,
    INVALIDSTATE := -1743714542,
    TRANSMODENOTSUPP := -1743714541,
    NOTIFYHNDINVALID := -1743714540,
    CLIENTUNKNOWN := -1743714539,
    NOMOREHDLS := -1743714538,
    INVALIDWATCHSIZE := -1743714537,
    NOTINIT := -1743714536,
    TIMEOUT := -1743714535,
    NOINTERFACE := -1743714534,
    INVALIDINTERFACE := -1743714533,
    INVALIDCLSID := -1743714532,
    INVALIDOBJID := -1743714531,
    PENDING := -1743714530,
    ABORTED := -1743714529,
    WARNING := -1743714528,
    INVALIDARRAYIDX := -1743714527,
    SYMBOLNOTACTIVE := -1743714526,
    ACCESSDENIED := -1743714525,
    LICENSENOTFOUND := -1743714524,
    LICENSEEXPIRED := -1743714523,
    LICENSEEXCEEDED := -1743714522,
    LICENSEINVALID := -1743714521,
    LICENSESYSTEMID := -1743714520,
    LICENSENOTIMELIMIT := -1743714519,
    LICENSEFUTUREISSUE := -1743714518,
    LICENSETIMETOLONG := -1743714517,
    EXCEPTION := -1743714516,
    LICENSEDUPLICATED := -1743714515,
    SIGNATUREINVALID := -1743714514,
    CERTIFICATEINVALID := -1743714513,
    LICENSEOEMNOTFOUND := -1743714512,
    LICENSERESTRICTED := -1743714511,
    LICENSEDEMODENIED := -1743714510,
    INVALIDFNCID := -1743714509,
    OUTOFRANGE := -1743714508,
    INVALIDALIGNMENT := -1743714507,
    LICENSEPLATFORM := -1743714506,
    FORWARD_PL := -1743714505,
    FORWARD_DL := -1743714504,
    FORWARD_RT := -1743714503
) DINT;
END_TYPE

