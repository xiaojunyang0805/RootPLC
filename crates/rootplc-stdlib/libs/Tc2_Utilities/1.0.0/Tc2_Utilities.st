(* Tc2_Utilities compatibility library for RootPLC (see library.toml).

   *_TO_HEXSTR: the value in hexadecimal, at least iPrecision digits (padded
   with zeros, never truncated); value 0 with iPrecision 0 gives ''. Upper
   case unless bLoCase. __ROOTPLC_HEXSTR is this library's own helper. *)

FUNCTION __ROOTPLC_HEXSTR : T_MaxString
VAR_INPUT
    value : LWORD;
    precision : INT;
    lower : BOOL;
END_VAR
VAR
    digits : STRING[16];
    rest : LWORD;
    text : T_MaxString;
END_VAR
IF lower THEN
    digits := '0123456789abcdef';
ELSE
    digits := '0123456789ABCDEF';
END_IF
rest := value;
text := '';
WHILE rest > 0 DO
    text := CONCAT(MID(digits, 1, LWORD_TO_INT(rest AND 16#F) + 1), text);
    rest := SHR(rest, 4);
END_WHILE
WHILE LEN(text) < precision DO
    text := CONCAT('0', text);
END_WHILE
__ROOTPLC_HEXSTR := text;
END_FUNCTION

FUNCTION BYTE_TO_HEXSTR : T_MaxString
VAR_INPUT
    in : BYTE;
    iPrecision : INT;
    bLoCase : BOOL := FALSE;
END_VAR
BYTE_TO_HEXSTR := __ROOTPLC_HEXSTR(BYTE_TO_LWORD(in), iPrecision, bLoCase);
END_FUNCTION

FUNCTION WORD_TO_HEXSTR : T_MaxString
VAR_INPUT
    in : WORD;
    iPrecision : INT;
    bLoCase : BOOL := FALSE;
END_VAR
WORD_TO_HEXSTR := __ROOTPLC_HEXSTR(WORD_TO_LWORD(in), iPrecision, bLoCase);
END_FUNCTION

FUNCTION DWORD_TO_HEXSTR : T_MaxString
VAR_INPUT
    in : DWORD;
    iPrecision : INT;
    bLoCase : BOOL := FALSE;
END_VAR
DWORD_TO_HEXSTR := __ROOTPLC_HEXSTR(DWORD_TO_LWORD(in), iPrecision, bLoCase);
END_FUNCTION

FUNCTION LWORD_TO_HEXSTR : T_MaxString
VAR_INPUT
    in : LWORD;
    iPrecision : INT;
    bLoCase : BOOL := FALSE;
END_VAR
LWORD_TO_HEXSTR := __ROOTPLC_HEXSTR(in, iPrecision, bLoCase);
END_FUNCTION

(* Argument descriptions for FB_FormatString: T_Arg names a variable by
   address; the F_ helpers fill one in for a variable of their type. *)
TYPE
    E_ArgType : (
        ARGTYPE_UNKNOWN := 0,
        ARGTYPE_BYTE,
        ARGTYPE_WORD,
        ARGTYPE_DWORD,
        ARGTYPE_REAL,
        ARGTYPE_LREAL,
        ARGTYPE_SINT,
        ARGTYPE_INT,
        ARGTYPE_DINT,
        ARGTYPE_USINT,
        ARGTYPE_UINT,
        ARGTYPE_UDINT,
        ARGTYPE_STRING,
        ARGTYPE_BOOL,
        ARGTYPE_BIGTYPE,
        ARGTYPE_ULARGE,
        ARGTYPE_UHUGE,
        ARGTYPE_LARGE,
        ARGTYPE_HUGE,
        ARGTYPE_LWORD
    );
    T_Arg : STRUCT
        eType : E_ArgType := E_ArgType#ARGTYPE_UNKNOWN;
        cbLen : UDINT := 0;
        pData : PVOID;
    END_STRUCT;
    TIMESTRUCT : STRUCT
        wYear : WORD;
        wMonth : WORD;
        wDayOfWeek : WORD;
        wDay : WORD;
        wHour : WORD;
        wMinute : WORD;
        wSecond : WORD;
        wMilliseconds : WORD;
    END_STRUCT;
END_TYPE

FUNCTION F_BOOL : T_Arg
VAR_IN_OUT
    in : BOOL;
END_VAR
F_BOOL.eType := E_ArgType#ARGTYPE_BOOL;
F_BOOL.cbLen := SIZEOF(in);
F_BOOL.pData := ADR(in);
END_FUNCTION

FUNCTION F_BYTE : T_Arg
VAR_IN_OUT
    in : BYTE;
END_VAR
F_BYTE.eType := E_ArgType#ARGTYPE_BYTE;
F_BYTE.cbLen := SIZEOF(in);
F_BYTE.pData := ADR(in);
END_FUNCTION

FUNCTION F_WORD : T_Arg
VAR_IN_OUT
    in : WORD;
END_VAR
F_WORD.eType := E_ArgType#ARGTYPE_WORD;
F_WORD.cbLen := SIZEOF(in);
F_WORD.pData := ADR(in);
END_FUNCTION

FUNCTION F_DWORD : T_Arg
VAR_IN_OUT
    in : DWORD;
END_VAR
F_DWORD.eType := E_ArgType#ARGTYPE_DWORD;
F_DWORD.cbLen := SIZEOF(in);
F_DWORD.pData := ADR(in);
END_FUNCTION

FUNCTION F_LWORD : T_Arg
VAR_IN_OUT
    in : LWORD;
END_VAR
F_LWORD.eType := E_ArgType#ARGTYPE_LWORD;
F_LWORD.cbLen := SIZEOF(in);
F_LWORD.pData := ADR(in);
END_FUNCTION

FUNCTION F_SINT : T_Arg
VAR_IN_OUT
    in : SINT;
END_VAR
F_SINT.eType := E_ArgType#ARGTYPE_SINT;
F_SINT.cbLen := SIZEOF(in);
F_SINT.pData := ADR(in);
END_FUNCTION

FUNCTION F_INT : T_Arg
VAR_IN_OUT
    in : INT;
END_VAR
F_INT.eType := E_ArgType#ARGTYPE_INT;
F_INT.cbLen := SIZEOF(in);
F_INT.pData := ADR(in);
END_FUNCTION

FUNCTION F_DINT : T_Arg
VAR_IN_OUT
    in : DINT;
END_VAR
F_DINT.eType := E_ArgType#ARGTYPE_DINT;
F_DINT.cbLen := SIZEOF(in);
F_DINT.pData := ADR(in);
END_FUNCTION

FUNCTION F_LINT : T_Arg
VAR_IN_OUT
    in : LINT;
END_VAR
F_LINT.eType := E_ArgType#ARGTYPE_LARGE;
F_LINT.cbLen := SIZEOF(in);
F_LINT.pData := ADR(in);
END_FUNCTION

FUNCTION F_USINT : T_Arg
VAR_IN_OUT
    in : USINT;
END_VAR
F_USINT.eType := E_ArgType#ARGTYPE_USINT;
F_USINT.cbLen := SIZEOF(in);
F_USINT.pData := ADR(in);
END_FUNCTION

FUNCTION F_UINT : T_Arg
VAR_IN_OUT
    in : UINT;
END_VAR
F_UINT.eType := E_ArgType#ARGTYPE_UINT;
F_UINT.cbLen := SIZEOF(in);
F_UINT.pData := ADR(in);
END_FUNCTION

FUNCTION F_UDINT : T_Arg
VAR_IN_OUT
    in : UDINT;
END_VAR
F_UDINT.eType := E_ArgType#ARGTYPE_UDINT;
F_UDINT.cbLen := SIZEOF(in);
F_UDINT.pData := ADR(in);
END_FUNCTION

FUNCTION F_ULINT : T_Arg
VAR_IN_OUT
    in : ULINT;
END_VAR
F_ULINT.eType := E_ArgType#ARGTYPE_ULARGE;
F_ULINT.cbLen := SIZEOF(in);
F_ULINT.pData := ADR(in);
END_FUNCTION

FUNCTION F_REAL : T_Arg
VAR_IN_OUT
    in : REAL;
END_VAR
F_REAL.eType := E_ArgType#ARGTYPE_REAL;
F_REAL.cbLen := SIZEOF(in);
F_REAL.pData := ADR(in);
END_FUNCTION

FUNCTION F_LREAL : T_Arg
VAR_IN_OUT
    in : LREAL;
END_VAR
F_LREAL.eType := E_ArgType#ARGTYPE_LREAL;
F_LREAL.cbLen := SIZEOF(in);
F_LREAL.pData := ADR(in);
END_FUNCTION

FUNCTION F_STRING : T_Arg
VAR_IN_OUT
    in : T_MaxString;
END_VAR
F_STRING.eType := E_ArgType#ARGTYPE_STRING;
F_STRING.cbLen := SIZEOF(in);
F_STRING.pData := ADR(in);
END_FUNCTION

(* Formats up to 10 arguments like fprintf. Declared only for now. *)
FUNCTION_BLOCK FB_FormatString
VAR_INPUT
    sFormat : T_MaxString;
    arg1 : T_Arg;
    arg2 : T_Arg;
    arg3 : T_Arg;
    arg4 : T_Arg;
    arg5 : T_Arg;
    arg6 : T_Arg;
    arg7 : T_Arg;
    arg8 : T_Arg;
    arg9 : T_Arg;
    arg10 : T_Arg;
END_VAR
VAR_OUTPUT
    bError : BOOL;
    nErrId : UDINT;
    sOut : T_MaxString;
END_VAR
END_FUNCTION_BLOCK

(* Case conversion: letters of Windows code page 1252 that STRING holds
   (Latin-1: A-Z and the accented letters); other characters are kept. *)
FUNCTION __ROOTPLC_MAPCHARS : T_MaxString
VAR_INPUT
    s : T_MaxString;
    src : STRING[64];
    dst : STRING[64];
END_VAR
VAR
    i, k : INT;
    c : STRING[1];
    text : T_MaxString;
END_VAR
text := '';
FOR i := 1 TO LEN(s) DO
    c := MID(s, 1, i);
    k := FIND(src, c);
    IF k > 0 THEN
        c := MID(dst, 1, k);
    END_IF
    text := CONCAT(text, c);
END_FOR
__ROOTPLC_MAPCHARS := text;
END_FUNCTION

FUNCTION F_ToLCase : T_MaxString
VAR_INPUT
    in : T_MaxString;
END_VAR
F_ToLCase := __ROOTPLC_MAPCHARS(in, 'ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ', 'abcdefghijklmnopqrstuvwxyzàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþ');
END_FUNCTION

FUNCTION F_ToUCase : T_MaxString
VAR_INPUT
    in : T_MaxString;
END_VAR
F_ToUCase := __ROOTPLC_MAPCHARS(in, 'abcdefghijklmnopqrstuvwxyzàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþ', 'ABCDEFGHIJKLMNOPQRSTUVWXYZÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ');
END_FUNCTION

(* Leading / trailing spaces removed. *)
FUNCTION F_LTrim : T_MaxString
VAR_INPUT
    in : T_MaxString;
END_VAR
VAR
    i : INT := 1;
END_VAR
WHILE i <= LEN(in) AND_THEN MID(in, 1, i) = ' ' DO
    i := i + 1;
END_WHILE
F_LTrim := RIGHT(in, LEN(in) - i + 1);
END_FUNCTION

FUNCTION F_RTrim : T_MaxString
VAR_INPUT
    in : T_MaxString;
END_VAR
VAR
    n : INT;
END_VAR
n := LEN(in);
WHILE n > 0 AND_THEN MID(in, 1, n) = ' ' DO
    n := n - 1;
END_WHILE
F_RTrim := LEFT(in, n);
END_FUNCTION
