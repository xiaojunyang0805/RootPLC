(* spec: [pous.oop.implements]
   expect: ok *)
INTERFACE I_Resettable
METHOD Reset
END_METHOD
END_INTERFACE

FUNCTION_BLOCK FB_Timer IMPLEMENTS I_Resettable
VAR
    t : INT;
END_VAR
METHOD Reset
t := 0;
END_METHOD
END_FUNCTION_BLOCK
