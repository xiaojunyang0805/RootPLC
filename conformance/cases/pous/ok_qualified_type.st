(* spec: [pous.type-spec]
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 3 *)
TYPE T_Count : INT; END_TYPE

FUNCTION_BLOCK FB_Base
VAR_OUTPUT
    n : MyLib.T_Count := 3;
END_VAR
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Derived EXTENDS MyLib.FB_Base
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    d : FB_Derived;
    n : INT;
END_VAR
n := d.n;
END_PROGRAM
