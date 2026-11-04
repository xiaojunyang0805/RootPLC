(* spec: [variables.static]
   expect: ok
   run: PRG_Main cycles=2
   assert: total = 6
   assert: mine = 2 *)
FUNCTION_BLOCK FB_Shared
VAR_OUTPUT
    calls : INT;
    own : INT;
END_VAR
VAR_STAT
    shared : INT;
END_VAR
shared := shared + 1;
own := own + 1;
calls := shared;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    a, b : FB_Shared;
    total, mine : INT;
END_VAR
a();
b();
b();
total := b.calls;
mine := a.own;
END_PROGRAM
