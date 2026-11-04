(* spec: [tests.whitebox] [pous.call.local-read]
   expect: error RP0203 *)
FUNCTION_BLOCK FB_Count
VAR
    hidden : INT;
END_VAR
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    c : FB_Count;
    n : INT;
END_VAR
c.hidden := n;   (* outside a TEST block internal variables are read-only *)
END_PROGRAM
