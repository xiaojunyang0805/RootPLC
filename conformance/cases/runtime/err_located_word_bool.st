(* spec: [runtime.image.type]
   expect: error RP0205 *)
PROGRAM WordBool
VAR
    lamp AT %QW0 : BOOL;
END_VAR
lamp := TRUE;
END_PROGRAM
