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
