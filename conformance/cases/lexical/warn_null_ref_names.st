(* spec: [lexical.keywords.soft]
   expect: warning RP0124
   run: PRG_Main cycles=1
   assert: k = 3
   assert: isNull = TRUE *)
TYPE E_DATA_STATE : (NULL, INIT, READY); END_TYPE
TYPE ST_X :
STRUCT
    Ref : INT;
END_STRUCT
END_TYPE

PROGRAM PRG_Main
VAR
    s : E_DATA_STATE := E_DATA_STATE#NULL;
    x : ST_X;
    k : INT;
    isNull : BOOL;
END_VAR
x.Ref := 3;
k := x.Ref;
isNull := s = E_DATA_STATE#NULL;
END_PROGRAM
