(* spec: [pous.stray-semicolon] [variables.declaration] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=1
   assert: x = 2
   assert: s.b = TRUE *)
TYPE E_Mode : (Idle, Run); END_TYPE;

TYPE ST_Pair :
STRUCT
    a : INT;;
    b : BOOL := TRUE;
END_STRUCT
END_TYPE

PROGRAM PRG_Main
VAR
    x : INT := 1;;
    m : E_Mode;
    s : ST_Pair;
END_VAR
x := x + 1;
END_PROGRAM;
