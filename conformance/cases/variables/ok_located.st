(* spec: [variables.located]
   expect: ok *)
PROGRAM PRG_Main
VAR
    button AT %IX0.0 : BOOL;
    lamp AT %QX0.1 : BOOL;
END_VAR
lamp := button;
END_PROGRAM
