(* spec: [pous.oop.modifiers]
   expect: ok
   run: PRG_Main cycles=1
   assert: v = 2 *)
FUNCTION_BLOCK PUBLIC FINAL FB_Two
METHOD PUBLIC Value : INT
Value := 2;
END_METHOD
METHOD PRIVATE Helper
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    t : FB_Two;
    v : INT;
END_VAR
v := t.Value();
END_PROGRAM
