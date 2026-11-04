(* spec: [stdlib.compat.query]
   libraries: TwinCAT_BuiltIns
   expect: warning RP0006
   run: PRG_Main cycles=1
   assert: hasExtra = TRUE
   assert: noExtra = FALSE
   assert: v = 42
   assert: gotPointer = TRUE *)
INTERFACE I_Base
METHOD Name : INT
END_METHOD
END_INTERFACE

INTERFACE I_Extra
METHOD Extra : INT
END_METHOD
END_INTERFACE

FUNCTION_BLOCK FB_A IMPLEMENTS I_Base, I_Extra
METHOD Name : INT
Name := 1;
END_METHOD
METHOD Extra : INT
Extra := 42;
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_B IMPLEMENTS I_Base
METHOD Name : INT
Name := 2;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    a : FB_A;
    b : FB_B;
    ib : I_Base;
    ie : I_Extra;
    p : REF_TO FB_A;
    hasExtra, noExtra, gotPointer : BOOL;
    v : INT;
END_VAR
ib := a;
hasExtra := __QUERYINTERFACE(ib, ie);
IF hasExtra THEN
    v := ie.Extra();
END_IF;
ib := b;
noExtra := __QUERYINTERFACE(ib, ie);
gotPointer := __QUERYPOINTER(a, p);
END_PROGRAM
