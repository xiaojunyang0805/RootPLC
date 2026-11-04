(* spec: [config.external] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=2
   assert: seen = 4 *)
VAR_GLOBAL
    total : INT;
END_VAR

FUNCTION_BLOCK FB_Add
VAR_EXTERNAL
    total : INT;
END_VAR
total := total + 1;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    a, b : FB_Add;
    seen : INT;
END_VAR
a();
b();
seen := total;
END_PROGRAM
