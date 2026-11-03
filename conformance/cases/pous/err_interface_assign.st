(* spec: [pous.oop.interface-ref]
   expect: error RP0103 *)
INTERFACE I_A
METHOD M : INT
END_METHOD
END_INTERFACE

FUNCTION_BLOCK FB_Z
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    a : I_A;
    z : FB_Z;
END_VAR
a := z;
END_PROGRAM
