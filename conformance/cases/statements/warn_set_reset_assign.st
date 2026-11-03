(* spec: [statements.assignment.set-reset]
   expect: warning RP0123
   run: PRG_Main cycles=1
   assert: a = TRUE
   assert: b = FALSE
   assert: c = TRUE *)
PROGRAM PRG_Main
VAR
    a : BOOL;
    b : BOOL := TRUE;
    c : BOOL := TRUE;
    go : BOOL := TRUE;
END_VAR
a S= go;
b R= go;
c R= NOT go;
END_PROGRAM
