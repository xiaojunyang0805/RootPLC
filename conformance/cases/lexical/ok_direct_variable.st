(* spec: [lexical.direct-variable]
   expect: ok *)
PROGRAM PRG_Main
VAR
    start_btn AT %IX0.0 : BOOL;
    lamp AT %QX0.1 : BOOL;
    level AT %IW2 : WORD;
    spare AT %I* : BOOL;
END_VAR

END_PROGRAM
