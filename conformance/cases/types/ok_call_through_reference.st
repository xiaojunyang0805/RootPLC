(* spec: [types.reference.alias] [pous.call.callee]
   expect: warning RP0118
   run: PRG_Main cycles=2
   assert: c.n = 4 *)
FUNCTION_BLOCK FB_Count
VAR_OUTPUT
    n : INT;
END_VAR
n := n + 1;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    c : FB_Count;
    r : REFERENCE TO FB_Count;
END_VAR
r REF= c;
r();          (* calls c through the reference *)
c();
END_PROGRAM
