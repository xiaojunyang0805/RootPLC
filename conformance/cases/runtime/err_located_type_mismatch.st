(* spec: [runtime.image.type]
   expect: error RP0205 *)
PROGRAM Mismatch
VAR
    level AT %IX0.0 : INT;
END_VAR
level := level + 1;
END_PROGRAM
