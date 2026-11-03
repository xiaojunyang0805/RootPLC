(* spec: [variables.section] [variables.declaration] [pous.program] [syntax.pragmas]
   expect: ok *)
PROGRAM PRG_Main
VAR_INPUT
    start, stop : BOOL;
END_VAR
VAR_OUTPUT
    running : BOOL;
END_VAR
VAR CONSTANT
    LIMIT : INT := 10;
END_VAR
VAR RETAIN
    {attribute 'hide'}
    count : DINT;
END_VAR
running := (start OR running) AND NOT stop;
END_PROGRAM
