(* spec: [pous.oop.upcast]
   expect: error RP0103 *)
FUNCTION_BLOCK Product
END_FUNCTION_BLOCK

FUNCTION_BLOCK Chips EXTENDS Product
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    b : Product;
    rb : REF_TO Product;
    rc : REF_TO Chips;
END_VAR
rb := REF(b);
rc := rb;
END_PROGRAM
