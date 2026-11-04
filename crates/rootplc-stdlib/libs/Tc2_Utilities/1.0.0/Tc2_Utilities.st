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

(* FB_FormatString: up to 10 arguments formatted like fprintf, after the
   format specification of the Tc2_Utilities manual (type, flags, width,
   precision; error codes 16#10 .. 16#8000 plus the argument number).
   Differences: REAL arguments for b, o, u, x (raw bit pattern) are not
   supported and give the type error 16#1000; e and E are not implemented
   (also not in TwinCAT): error 16#800. The values of E_HashPrefixTypes are
   not published; RootPLC numbers them in order. *)
TYPE
    E_HashPrefixTypes : (HASHPREFIX_IEC, HASHPREFIX_STDC);
    E_SBCSType : (eSBCS_WesternEuropean := 1, eSBCS_CentralEuropean := 2);
END_TYPE

VAR_GLOBAL
    GLOBAL_FORMAT_HASH_PREFIX_TYPE : E_HashPrefixTypes := E_HashPrefixTypes#HASHPREFIX_IEC;
    (* F_ToLCase / F_ToUCase use code page 1252; 1250 letters do not fit
       RootPLC's Latin-1 STRING *)
    GLOBAL_SBCS_TABLE : E_SBCSType := E_SBCSType#eSBCS_WesternEuropean;
END_VAR

(* Digits of value in base 2, 8, 10 or 16, at least minDigits long. *)
FUNCTION __ROOTPLC_DIGITS : T_MaxString
VAR_INPUT
    value : ULINT;
    base : ULINT;
    upper : BOOL;
    minDigits : INT;
END_VAR
VAR
    digits : STRING[16];
    rest : ULINT;
    text : T_MaxString;
END_VAR
IF upper THEN
    digits := '0123456789ABCDEF';
ELSE
    digits := '0123456789abcdef';
END_IF
rest := value;
text := '';
WHILE rest > 0 DO
    text := CONCAT(MID(digits, 1, ULINT_TO_INT(rest MOD base) + 1), text);
    rest := rest / base;
END_WHILE
WHILE LEN(text) < minDigits DO
    text := CONCAT('0', text);
END_WHILE
__ROOTPLC_DIGITS := text;
END_FUNCTION

(* ABS(x) with prec decimal places, rounded; '' if longer than 250
   characters. Above 1E15 the integer digits beyond LREAL precision are
   written as zeros. *)
FUNCTION __ROOTPLC_FIXED : T_MaxString
VAR_INPUT
    x : LREAL;
    prec : INT;
END_VAR
VAR
    v, scale, q : LREAL;
    scaled, unit : ULINT;
    intPart, frac : T_MaxString;
    i, k : INT;
END_VAR
v := ABS(x);
scale := 1.0;
FOR i := 1 TO prec DO
    scale := scale * 10.0;
END_FOR
IF prec <= 18 AND_THEN v * scale < 9.0E18 THEN
    unit := LREAL_TO_ULINT(scale);
    scaled := LREAL_TO_ULINT(v * scale);
    frac := __ROOTPLC_DIGITS(scaled MOD unit, 10, FALSE, prec);
    intPart := __ROOTPLC_DIGITS(scaled / unit, 10, FALSE, 1);
ELSE
    k := 0;
    q := v;
    WHILE q >= 1.0E15 DO
        q := q / 10.0;
        k := k + 1;
    END_WHILE
    intPart := __ROOTPLC_DIGITS(LREAL_TO_ULINT(q), 10, FALSE, 1);
    IF LEN(intPart) + k + prec > 250 THEN
        __ROOTPLC_FIXED := '';
        RETURN;
    END_IF
    FOR i := 1 TO k DO
        intPart := CONCAT(intPart, '0');
    END_FOR
    frac := '';
    FOR i := 1 TO prec DO
        frac := CONCAT(frac, '0');
    END_FOR
END_IF
IF prec > 0 THEN
    __ROOTPLC_FIXED := CONCAT(CONCAT(intPart, '.'), frac);
ELSE
    __ROOTPLC_FIXED := intPart;
END_IF
END_FUNCTION

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
VAR
    args : ARRAY[1..10] OF T_Arg;
    used : INT;
    pos, n, state, width, prec : INT;
    c, t : STRING[1];
    fMinus, fPlus, fZero, fSpace, fHash, widthStar, precStar, havePrec : BOOL;
    text, piece, prefix, sign : T_MaxString;
    err : UDINT;
    a : T_Arg;
    isU, isS, isR, isStr : BOOL;
    raw, mag, span : ULINT;
    sv : LINT;
    rv : LREAL;
    pBYTE : REF_TO BYTE;
    pWORD : REF_TO WORD;
    pDWORD : REF_TO DWORD;
    pLWORD : REF_TO LWORD;
    pUSINT : REF_TO USINT;
    pUINT : REF_TO UINT;
    pUDINT : REF_TO UDINT;
    pULINT : REF_TO ULINT;
    pSINT : REF_TO SINT;
    pINT : REF_TO INT;
    pDINT : REF_TO DINT;
    pLINT : REF_TO LINT;
    pREAL : REF_TO REAL;
    pLREAL : REF_TO LREAL;
    pSTR : REF_TO T_MaxString;
    fill : STRING[1];
    base : ULINT;
    k : INT;
END_VAR
args[1] := arg1;
args[2] := arg2;
args[3] := arg3;
args[4] := arg4;
args[5] := arg5;
args[6] := arg6;
args[7] := arg7;
args[8] := arg8;
args[9] := arg9;
args[10] := arg10;
text := '';
err := 0;
used := 0;
pos := 1;
n := LEN(sFormat);
WHILE pos <= n AND err = 0 DO
    c := MID(sFormat, 1, pos);
    pos := pos + 1;
    IF c <> '%' THEN
        piece := c;
    ELSIF pos <= n AND_THEN MID(sFormat, 1, pos) = '%' THEN
        piece := '%';
        pos := pos + 1;
    ELSE
        (* parameter fields: flags, width, .precision, type *)
        fMinus := FALSE;
        fPlus := FALSE;
        fZero := FALSE;
        fSpace := FALSE;
        fHash := FALSE;
        widthStar := FALSE;
        precStar := FALSE;
        havePrec := FALSE;
        width := 0;
        prec := -1;
        state := 0; (* 0 flags, 1 width, 2 after '.', 3 precision *)
        t := '';
        WHILE t = '' AND err = 0 DO
            IF pos > n THEN
                err := 16#10;
            ELSE
                c := MID(sFormat, 1, pos);
                pos := pos + 1;
                IF FIND('-+ #', c) > 0 OR (c = '0' AND state = 0) THEN
                    IF state <> 0 THEN
                        err := 16#100;
                    ELSIF c = '-' THEN
                        fMinus := TRUE;
                    ELSIF c = '+' THEN
                        fPlus := TRUE;
                    ELSIF c = ' ' THEN
                        fSpace := TRUE;
                    ELSIF c = '#' THEN
                        fHash := TRUE;
                    ELSE
                        fZero := TRUE;
                    END_IF
                ELSIF FIND('0123456789', c) > 0 THEN
                    IF state <= 1 AND NOT widthStar THEN
                        width := width * 10 + FIND('0123456789', c) - 1;
                        state := 1;
                        IF width > 255 THEN
                            err := 16#40;
                        END_IF
                    ELSIF state >= 2 AND NOT precStar THEN
                        IF prec < 0 THEN
                            prec := 0;
                        END_IF
                        prec := prec * 10 + FIND('0123456789', c) - 1;
                        state := 3;
                        IF prec > 255 THEN
                            err := 16#80;
                        END_IF
                    ELSE
                        err := 16#200;
                    END_IF
                ELSIF c = '*' THEN
                    IF state = 0 THEN
                        widthStar := TRUE;
                        state := 1;
                    ELSIF state = 2 THEN
                        precStar := TRUE;
                        state := 3;
                    ELSE
                        err := 16#20;
                    END_IF
                ELSIF c = '.' THEN
                    IF state <= 1 THEN
                        state := 2;
                        havePrec := TRUE;
                    ELSE
                        err := 16#400;
                    END_IF
                ELSIF c = '%' THEN
                    err := 16#10;
                ELSIF FIND('bBoOuUcCfFdDsSxX', c) > 0 THEN
                    t := c;
                ELSE
                    err := 16#800;
                END_IF
            END_IF
        END_WHILE
        IF err = 0 THEN
            (* the value, then the width and precision arguments *)
            used := used + 1;
            IF used > 10 THEN
                err := 16#4000;
            ELSE
                a := args[used];
                IF a.eType = E_ArgType#ARGTYPE_UNKNOWN THEN
                    err := 16#4000;
                END_IF
            END_IF
            IF err = 0 AND widthStar THEN
                used := used + 1;
                IF used > 10 THEN
                    err := 16#4000;
                ELSE
                    width := __ROOTPLC_STARARG(args[used]);
                    IF width < 0 THEN
                        err := 16#40;
                    END_IF
                END_IF
            END_IF
            IF err = 0 AND precStar THEN
                used := used + 1;
                IF used > 10 THEN
                    err := 16#4000;
                ELSE
                    prec := __ROOTPLC_STARARG(args[used]);
                    IF prec < 0 THEN
                        err := 16#80;
                    END_IF
                END_IF
            END_IF
        END_IF
        IF err = 0 THEN
            (* read the argument *)
            isU := FALSE;
            isS := FALSE;
            isR := FALSE;
            isStr := FALSE;
            raw := 0;
            sv := 0;
            rv := 0.0;
            CASE a.eType OF
                E_ArgType#ARGTYPE_BYTE:
                    pBYTE := a.pData;
                    raw := BYTE_TO_ULINT(pBYTE^);
                    isU := TRUE;
                E_ArgType#ARGTYPE_WORD:
                    pWORD := a.pData;
                    raw := WORD_TO_ULINT(pWORD^);
                    isU := TRUE;
                E_ArgType#ARGTYPE_DWORD:
                    pDWORD := a.pData;
                    raw := DWORD_TO_ULINT(pDWORD^);
                    isU := TRUE;
                E_ArgType#ARGTYPE_LWORD:
                    pLWORD := a.pData;
                    raw := LWORD_TO_ULINT(pLWORD^);
                    isU := TRUE;
                E_ArgType#ARGTYPE_USINT:
                    pUSINT := a.pData;
                    raw := USINT_TO_ULINT(pUSINT^);
                    isU := TRUE;
                E_ArgType#ARGTYPE_UINT:
                    pUINT := a.pData;
                    raw := UINT_TO_ULINT(pUINT^);
                    isU := TRUE;
                E_ArgType#ARGTYPE_UDINT:
                    pUDINT := a.pData;
                    raw := UDINT_TO_ULINT(pUDINT^);
                    isU := TRUE;
                E_ArgType#ARGTYPE_ULARGE:
                    pULINT := a.pData;
                    raw := pULINT^;
                    isU := TRUE;
                E_ArgType#ARGTYPE_SINT:
                    pSINT := a.pData;
                    sv := SINT_TO_LINT(pSINT^);
                    isS := TRUE;
                E_ArgType#ARGTYPE_INT:
                    pINT := a.pData;
                    sv := INT_TO_LINT(pINT^);
                    isS := TRUE;
                E_ArgType#ARGTYPE_DINT:
                    pDINT := a.pData;
                    sv := DINT_TO_LINT(pDINT^);
                    isS := TRUE;
                E_ArgType#ARGTYPE_LARGE:
                    pLINT := a.pData;
                    sv := pLINT^;
                    isS := TRUE;
                E_ArgType#ARGTYPE_REAL:
                    pREAL := a.pData;
                    rv := REAL_TO_LREAL(pREAL^);
                    isR := TRUE;
                E_ArgType#ARGTYPE_LREAL:
                    pLREAL := a.pData;
                    rv := pLREAL^;
                    isR := TRUE;
                E_ArgType#ARGTYPE_STRING:
                    pSTR := a.pData;
                    isStr := TRUE;
            END_CASE
            IF isS THEN
                (* the content of a signed type as an unsigned number of its size *)
                IF sv >= 0 THEN
                    raw := LINT_TO_ULINT(sv);
                    mag := raw;
                ELSE
                    mag := LINT_TO_ULINT(-(sv + 1)) + 1;
                    (* two's complement, cut to the argument's size *)
                    raw := LINT_TO_ULINT(sv);
                    IF a.cbLen < 8 THEN
                        span := 1;
                        FOR k := 1 TO UDINT_TO_INT(a.cbLen) * 8 DO
                            span := span * 2;
                        END_FOR
                        raw := raw MOD span;
                    END_IF
                END_IF
            ELSE
                mag := raw;
            END_IF
            piece := '';
            prefix := '';
            sign := '';
            fill := ' ';
            IF FIND('bBoOxXuU', t) > 0 THEN
                IF NOT (isU OR isS) THEN
                    err := 16#1000;
                ELSE
                    IF t = 'b' OR t = 'B' THEN
                        base := 2;
                    ELSIF t = 'o' OR t = 'O' THEN
                        base := 8;
                    ELSIF t = 'u' OR t = 'U' THEN
                        base := 10;
                    ELSE
                        base := 16;
                    END_IF
                    IF prec < 0 THEN
                        prec := 1;
                    END_IF
                    piece := __ROOTPLC_DIGITS(raw, base, t = 'X', prec);
                    IF fHash AND base <> 10 THEN
                        IF GLOBAL_FORMAT_HASH_PREFIX_TYPE = E_HashPrefixTypes#HASHPREFIX_STDC THEN
                            IF base = 8 THEN
                                prefix := '0';
                            ELSIF base = 16 AND t = 'X' THEN
                                prefix := '0X';
                            ELSIF base = 16 THEN
                                prefix := '0x';
                            END_IF
                        ELSIF base = 2 THEN
                            prefix := '2#';
                        ELSIF base = 8 THEN
                            prefix := '8#';
                        ELSE
                            prefix := '16#';
                        END_IF
                    END_IF
                END_IF
            ELSIF t = 'd' OR t = 'D' THEN
                IF NOT (isU OR isS) THEN
                    err := 16#1000;
                ELSE
                    IF prec < 0 THEN
                        prec := 1;
                    END_IF
                    piece := __ROOTPLC_DIGITS(mag, 10, FALSE, prec);
                    IF isS AND sv < 0 THEN
                        sign := '-';
                    ELSIF fPlus THEN
                        sign := '+';
                    ELSIF fSpace THEN
                        sign := ' ';
                    END_IF
                END_IF
            ELSIF t = 'c' OR t = 'C' THEN
                IF a.eType = E_ArgType#ARGTYPE_BYTE OR a.eType = E_ArgType#ARGTYPE_USINT THEN
                    piece := CHAR_TO_STRING(BYTE_TO_CHAR(ULINT_TO_BYTE(raw)));
                ELSE
                    err := 16#1000;
                END_IF
            ELSIF t = 'f' OR t = 'F' THEN
                IF NOT isR THEN
                    err := 16#1000;
                ELSE
                    IF prec < 0 THEN
                        prec := 6;
                    END_IF
                    IF rv <> rv THEN
                        piece := '#QNAN';
                    ELSIF rv > 1.7976931348623157E308 OR rv < -1.7976931348623157E308 THEN
                        piece := '#INF';
                    ELSE
                        piece := __ROOTPLC_FIXED(rv, prec);
                        IF piece = '' THEN
                            piece := '#OVF';
                        END_IF
                    END_IF
                    IF rv < 0.0 THEN
                        sign := '-';
                    ELSIF fPlus THEN
                        sign := '+';
                    ELSIF fSpace THEN
                        sign := ' ';
                    END_IF
                    IF fZero AND NOT fMinus THEN
                        fill := '0';
                    END_IF
                END_IF
            ELSE
                (* s, S *)
                IF NOT isStr THEN
                    err := 16#1000;
                ELSE
                    piece := pSTR^;
                    IF havePrec AND prec >= 0 AND prec < LEN(piece) THEN
                        piece := LEFT(piece, prec);
                    END_IF
                    IF fZero AND NOT fMinus THEN
                        fill := '0';
                    END_IF
                END_IF
            END_IF
            IF err = 0 THEN
                piece := CONCAT(prefix, piece);
                IF fill = '0' THEN
                    (* zeros go between the sign and the digits *)
                    FOR k := LEN(sign) + LEN(piece) + 1 TO width DO
                        piece := CONCAT('0', piece);
                    END_FOR
                    piece := CONCAT(sign, piece);
                ELSE
                    piece := CONCAT(sign, piece);
                    FOR k := LEN(piece) + 1 TO width DO
                        IF fMinus THEN
                            piece := CONCAT(piece, ' ');
                        ELSE
                            piece := CONCAT(' ', piece);
                        END_IF
                    END_FOR
                END_IF
            END_IF
        END_IF
        IF err <> 0 THEN
            err := err + INT_TO_UDINT(MAX(used, 1));
        END_IF
    END_IF
    IF err = 0 THEN
        IF LEN(text) + LEN(piece) > 255 THEN
            err := 16#8000 + INT_TO_UDINT(MAX(used, 1));
        ELSE
            text := CONCAT(text, piece);
        END_IF
    END_IF
END_WHILE
bError := err <> 0;
nErrId := err;
IF bError THEN
    sOut := '';
ELSE
    sOut := text;
END_IF
END_FUNCTION_BLOCK

(* The value of a width or precision argument given by '*' (BYTE, WORD,
   DWORD, USINT, UINT, UDINT), or -1. *)
FUNCTION __ROOTPLC_STARARG : INT
VAR_INPUT
    a : T_Arg;
END_VAR
VAR
    pBYTE : REF_TO BYTE;
    pWORD : REF_TO WORD;
    pDWORD : REF_TO DWORD;
    pUSINT : REF_TO USINT;
    pUINT : REF_TO UINT;
    pUDINT : REF_TO UDINT;
    v : UDINT;
END_VAR
CASE a.eType OF
    E_ArgType#ARGTYPE_BYTE:
        pBYTE := a.pData;
        v := BYTE_TO_UDINT(pBYTE^);
    E_ArgType#ARGTYPE_WORD:
        pWORD := a.pData;
        v := WORD_TO_UDINT(pWORD^);
    E_ArgType#ARGTYPE_DWORD:
        pDWORD := a.pData;
        v := DWORD_TO_UDINT(pDWORD^);
    E_ArgType#ARGTYPE_USINT:
        pUSINT := a.pData;
        v := USINT_TO_UDINT(pUSINT^);
    E_ArgType#ARGTYPE_UINT:
        pUINT := a.pData;
        v := UINT_TO_UDINT(pUINT^);
    E_ArgType#ARGTYPE_UDINT:
        pUDINT := a.pData;
        v := pUDINT^;
ELSE
    __ROOTPLC_STARARG := -1;
    RETURN;
END_CASE
IF v > 255 THEN
    __ROOTPLC_STARARG := -1;
ELSE
    __ROOTPLC_STARARG := UDINT_TO_INT(v);
END_IF
END_FUNCTION

(* Time types and conversions (TIMESTRUCT, FILETIME, DT). FILETIME counts
   100 ns since 1601-01-01; DT counts seconds since 1970-01-01. *)
TYPE
    T_FILETIME : STRUCT
        dwLowDateTime : DWORD;
        dwHighDateTime : DWORD;
    END_STRUCT;
    T_FILETIME64 : ULINT;
    E_TimeZoneID : (
        eTimeZoneID_Invalid := -1,
        eTimeZoneID_Unknown := 0,
        eTimeZoneID_Standard := 1,
        eTimeZoneID_Daylight := 2
    ) DINT;
    ST_TimeZoneInformation : STRUCT
        bias : DINT;
        standardName : STRING[31];
        standardDate : TIMESTRUCT;
        standardBias : DINT;
        daylightName : STRING[31];
        daylightDate : TIMESTRUCT;
        daylightBias : DINT;
    END_STRUCT;
END_TYPE

(* Days since 1970-01-01 of a civil date (proleptic Gregorian). *)
FUNCTION __ROOTPLC_DAYS : LINT
VAR_INPUT
    y, m, d : LINT;
END_VAR
VAR
    era, yoe, doy, doe, mm : LINT;
END_VAR
IF m <= 2 THEN
    y := y - 1;
    mm := m + 9;
ELSE
    mm := m - 3;
END_IF
era := y / 400;
yoe := y - era * 400;
doy := (153 * mm + 2) / 5 + d - 1;
doe := yoe * 365 + yoe / 4 - yoe / 100 + doy;
__ROOTPLC_DAYS := era * 146097 + doe - 719468;
END_FUNCTION

(* The civil date and time of a number of milliseconds since 1970-01-01. *)
FUNCTION __ROOTPLC_TIMESTRUCT : TIMESTRUCT
VAR_INPUT
    ms : LINT;
END_VAR
VAR
    z, sod, era, doe, yoe, y, doy, mp, d, m : LINT;
END_VAR
z := ms / 86400000;
sod := ms - z * 86400000;
IF sod < 0 THEN
    sod := sod + 86400000;
    z := z - 1;
END_IF
__ROOTPLC_TIMESTRUCT.wDayOfWeek := LINT_TO_WORD(((z MOD 7) + 11) MOD 7);
z := z + 719468;
era := z / 146097;
doe := z - era * 146097;
yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
y := yoe + era * 400;
doy := doe - (365 * yoe + yoe / 4 - yoe / 100);
mp := (5 * doy + 2) / 153;
d := doy - (153 * mp + 2) / 5 + 1;
IF mp < 10 THEN
    m := mp + 3;
ELSE
    m := mp - 9;
END_IF
IF m <= 2 THEN
    y := y + 1;
END_IF
__ROOTPLC_TIMESTRUCT.wYear := LINT_TO_WORD(y);
__ROOTPLC_TIMESTRUCT.wMonth := LINT_TO_WORD(m);
__ROOTPLC_TIMESTRUCT.wDay := LINT_TO_WORD(d);
__ROOTPLC_TIMESTRUCT.wHour := LINT_TO_WORD(sod / 3600000);
__ROOTPLC_TIMESTRUCT.wMinute := LINT_TO_WORD((sod / 60000) MOD 60);
__ROOTPLC_TIMESTRUCT.wSecond := LINT_TO_WORD((sod / 1000) MOD 60);
__ROOTPLC_TIMESTRUCT.wMilliseconds := LINT_TO_WORD(sod MOD 1000);
END_FUNCTION

(* Milliseconds since 1970-01-01 of a TIMESTRUCT (wDayOfWeek ignored). *)
FUNCTION __ROOTPLC_MILLIS : LINT
VAR_INPUT
    t : TIMESTRUCT;
END_VAR
__ROOTPLC_MILLIS := __ROOTPLC_DAYS(WORD_TO_LINT(t.wYear), WORD_TO_LINT(t.wMonth), WORD_TO_LINT(t.wDay)) * 86400000
    + WORD_TO_LINT(t.wHour) * 3600000 + WORD_TO_LINT(t.wMinute) * 60000
    + WORD_TO_LINT(t.wSecond) * 1000 + WORD_TO_LINT(t.wMilliseconds);
END_FUNCTION

FUNCTION DT_TO_SYSTEMTIME : TIMESTRUCT
VAR_INPUT
    DTIN : DT;
END_VAR
DT_TO_SYSTEMTIME := __ROOTPLC_TIMESTRUCT(DT_TO_LINT(DTIN) * 1000);
END_FUNCTION

(* Milliseconds are rounded to the nearest second. *)
FUNCTION SYSTEMTIME_TO_DT : DT
VAR_INPUT
    TIMESTR : TIMESTRUCT;
END_VAR
SYSTEMTIME_TO_DT := LINT_TO_DT((__ROOTPLC_MILLIS(TIMESTR) + 500) / 1000);
END_FUNCTION

(* 1601-01-01 is 11644473600 s before 1970-01-01. The conversion fails
   (all members zero) if the most significant bit is set. *)
FUNCTION FILETIME64_TO_SYSTEMTIME : TIMESTRUCT
VAR_INPUT
    fileTime : T_FILETIME64;
END_VAR
IF fileTime >= ULINT#16#8000000000000000 THEN
    RETURN;
END_IF
FILETIME64_TO_SYSTEMTIME := __ROOTPLC_TIMESTRUCT(ULINT_TO_LINT(fileTime / 10000) - 11644473600000);
END_FUNCTION

FUNCTION SYSTEMTIME_TO_FILETIME64 : T_FILETIME64
VAR_INPUT
    systemTime : TIMESTRUCT;
END_VAR
SYSTEMTIME_TO_FILETIME64 := LINT_TO_ULINT(__ROOTPLC_MILLIS(systemTime) + 11644473600000) * 10000;
END_FUNCTION

FUNCTION SYSTEMTIME_TO_FILETIME : T_FILETIME
VAR_INPUT
    systemTime : TIMESTRUCT;
END_VAR
VAR
    ft : ULINT;
END_VAR
ft := SYSTEMTIME_TO_FILETIME64(systemTime);
SYSTEMTIME_TO_FILETIME.dwLowDateTime := ULINT_TO_DWORD(ft MOD 4294967296);
SYSTEMTIME_TO_FILETIME.dwHighDateTime := ULINT_TO_DWORD(ft / 4294967296);
END_FUNCTION

(* 'YYYY-MM-DD-hh:mm:ss.xxx' *)
FUNCTION SYSTEMTIME_TO_STRING : STRING[24]
VAR_INPUT
    in : TIMESTRUCT;
END_VAR
VAR
    s : STRING[24];
END_VAR
s := CONCAT(__ROOTPLC_DIGITS(WORD_TO_ULINT(in.wYear), 10, FALSE, 4), '-');
s := CONCAT(CONCAT(s, __ROOTPLC_DIGITS(WORD_TO_ULINT(in.wMonth), 10, FALSE, 2)), '-');
s := CONCAT(CONCAT(s, __ROOTPLC_DIGITS(WORD_TO_ULINT(in.wDay), 10, FALSE, 2)), '-');
s := CONCAT(CONCAT(s, __ROOTPLC_DIGITS(WORD_TO_ULINT(in.wHour), 10, FALSE, 2)), ':');
s := CONCAT(CONCAT(s, __ROOTPLC_DIGITS(WORD_TO_ULINT(in.wMinute), 10, FALSE, 2)), ':');
s := CONCAT(CONCAT(s, __ROOTPLC_DIGITS(WORD_TO_ULINT(in.wSecond), 10, FALSE, 2)), '.');
SYSTEMTIME_TO_STRING := CONCAT(s, __ROOTPLC_DIGITS(WORD_TO_ULINT(in.wMilliseconds), 10, FALSE, 3));
END_FUNCTION

(* [-]dddd.dddd with iPrecision decimals, rounded if bRound, else cut. *)
FUNCTION LREAL_TO_FMTSTR : STRING[510]
VAR_INPUT
    in : LREAL;
    iPrecision : INT;
    bRound : BOOL;
END_VAR
VAR
    sign : STRING[1];
    body : T_MaxString;
    v, scale : LREAL;
    i : INT;
END_VAR
IF in <> in THEN
    LREAL_TO_FMTSTR := '#QNAN';
    RETURN;
END_IF
IF in < 0.0 THEN
    sign := '-';
ELSE
    sign := '';
END_IF
IF ABS(in) > 1.7976931348623157E308 THEN
    LREAL_TO_FMTSTR := CONCAT(sign, '#INF');
    RETURN;
END_IF
v := ABS(in);
IF NOT bRound THEN
    (* cut after iPrecision decimals: round down at that place *)
    scale := 1.0;
    FOR i := 1 TO iPrecision DO
        scale := scale * 10.0;
    END_FOR
    IF v * scale < 9.0E18 THEN
        v := ULINT_TO_LREAL(LREAL_TO_ULINT(v * scale - 0.5)) / scale;
        IF v < 0.0 THEN
            v := 0.0;
        END_IF
    END_IF
END_IF
body := __ROOTPLC_FIXED(v, MAX(iPrecision, 0));
IF body = '' THEN
    LREAL_TO_FMTSTR := CONCAT(sign, '#OVF');
ELSIF v = 0.0 THEN
    LREAL_TO_FMTSTR := body;
ELSE
    LREAL_TO_FMTSTR := CONCAT(sign, body);
END_IF
END_FUNCTION

(* String lengths and copies through pointers. *)
FUNCTION LEN2 : UDINT
VAR_INPUT
    pSTRING : POINTER TO STRING;
END_VAR
IF pSTRING <> 0 THEN
    LEN2 := INT_TO_UDINT(LEN(pSTRING^));
END_IF
END_FUNCTION

FUNCTION WLEN2 : UDINT
VAR_INPUT
    pWSTRING : POINTER TO WSTRING;
END_VAR
IF pWSTRING <> 0 THEN
    WLEN2 := INT_TO_UDINT(LEN(pWSTRING^));
END_IF
END_FUNCTION

(* TRUE if the whole string fitted into nDstSize bytes (with the null). *)
FUNCTION STRNCPY : BOOL
VAR_INPUT
    pDst : POINTER TO STRING;
    pSrc : POINTER TO STRING;
    nDstSize : UDINT;
END_VAR
VAR_OUTPUT
    nSrcLen : UDINT;
    nDstLen : UDINT;
END_VAR
IF pDst = 0 OR pSrc = 0 OR nDstSize = 0 THEN
    RETURN;
END_IF
nSrcLen := INT_TO_UDINT(LEN(pSrc^));
nDstLen := MIN(nSrcLen, nDstSize - 1);
pDst^ := LEFT(pSrc^, UDINT_TO_INT(nDstLen));
STRNCPY := nDstLen = nSrcLen;
END_FUNCTION

FUNCTION WSTRING_TO_STRING2 : BOOL
VAR_INPUT
    pDstString : POINTER TO STRING;
    pSrcWString : POINTER TO WSTRING;
    nDstSize : UDINT;
END_VAR
VAR
    s : T_MaxString;
END_VAR
IF pDstString = 0 OR pSrcWString = 0 OR nDstSize = 0 THEN
    RETURN;
END_IF
s := WSTRING_TO_STRING(pSrcWString^);
pDstString^ := LEFT(s, UDINT_TO_INT(MIN(INT_TO_UDINT(LEN(s)), nDstSize - 1)));
WSTRING_TO_STRING2 := INT_TO_UDINT(LEN(s)) <= nDstSize - 1;
END_FUNCTION

(* Blocks that read the operating system (clock, time zone) or manage raw
   memory: declared only. *)
FUNCTION_BLOCK FB_LocalSystemTime
VAR_INPUT
    sNetID : T_AmsNetId := '';
    bEnable : BOOL;
    dwCycle : DWORD := 5;
    dwOpt : DWORD := 1;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bValid : BOOL;
    systemTime : TIMESTRUCT;
    tzID : E_TimeZoneID := E_TimeZoneID#eTimeZoneID_Invalid;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK NT_GetTime
VAR_INPUT
    NETID : T_AmsNetId;
    START : BOOL;
    TMOUT : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    BUSY : BOOL;
    ERR : BOOL;
    ERRID : UDINT;
    TIMESTR : TIMESTRUCT;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_GetTimeZoneInformation
VAR_INPUT
    sNetID : T_AmsNetId;
    bExecute : BOOL;
    tTimeout : TIME := DEFAULT_ADS_TIMEOUT;
END_VAR
VAR_OUTPUT
    bBusy : BOOL;
    bError : BOOL;
    nErrID : UDINT;
    tzID : E_TimeZoneID;
    tzInfo : ST_TimeZoneInformation;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_MemRingBuffer
VAR_INPUT
    pWrite : POINTER TO BYTE;
    cbWrite : UDINT;
    pRead : POINTER TO BYTE;
    cbRead : UDINT;
    pBuffer : POINTER TO BYTE;
    cbBuffer : UDINT;
END_VAR
VAR_OUTPUT
    bOk : BOOL;
    nCount : UDINT;
    cbSize : UDINT;
    cbReturn : UDINT;
END_VAR
END_FUNCTION_BLOCK

(* Byte order: host (little endian) to network (big endian) and back. *)
FUNCTION HOST_TO_BE16 : WORD
VAR_INPUT
    in : WORD;
END_VAR
HOST_TO_BE16 := ROL(in, 8);
END_FUNCTION

FUNCTION BE16_TO_HOST : WORD
VAR_INPUT
    in : WORD;
END_VAR
BE16_TO_HOST := ROL(in, 8);
END_FUNCTION

FUNCTION HOST_TO_BE32 : DWORD
VAR_INPUT
    in : DWORD;
END_VAR
HOST_TO_BE32 := SHL(in AND 16#FF, 24) OR SHL(in AND 16#FF00, 8)
    OR (SHR(in, 8) AND 16#FF00) OR SHR(in, 24);
END_FUNCTION

FUNCTION BE32_TO_HOST : DWORD
VAR_INPUT
    in : DWORD;
END_VAR
BE32_TO_HOST := HOST_TO_BE32(in);
END_FUNCTION

(* LREAL tests: NaN, and finite (neither infinite nor NaN). *)
FUNCTION LrealIsNaN : BOOL
VAR_INPUT
    x : REFERENCE TO LREAL;
END_VAR
LrealIsNaN := x <> x;
END_FUNCTION

FUNCTION LrealIsFinite : BOOL
VAR_INPUT
    x : REFERENCE TO LREAL;
END_VAR
LrealIsFinite := x = x AND ABS(x) <= 1.7976931348623157E308;
END_FUNCTION

(* IsFinite for a REAL or LREAL argument (T_Arg); FALSE for other types. *)
FUNCTION IsFinite : BOOL
VAR_INPUT
    x : T_Arg;
END_VAR
VAR
    pR : REF_TO REAL;
    pL : REF_TO LREAL;
    v : LREAL;
END_VAR
IF x.eType = E_ArgType#ARGTYPE_REAL THEN
    pR := x.pData;
    v := REAL_TO_LREAL(pR^);
ELSIF x.eType = E_ArgType#ARGTYPE_LREAL THEN
    pL := x.pData;
    v := pL^;
ELSE
    RETURN;
END_IF
IsFinite := v = v AND ABS(v) <= 1.7976931348623157E308;
END_FUNCTION
