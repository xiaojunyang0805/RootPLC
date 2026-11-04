(* spec: [pous.call.callee]
   expect: error RP0132 *)
PROGRAM PRG_Main
VAR
    b : BOOL;
    i : INT;
END_VAR
i := b(1);   (* b is a variable, not a function *)
END_PROGRAM
