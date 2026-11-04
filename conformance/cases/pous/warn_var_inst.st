(* spec: [pous.oop.method] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=3
   assert: a = 3
   assert: b = 3 *)
FUNCTION_BLOCK FB_Counter
METHOD Next : INT
VAR_INST
    calls : INT;
END_VAR
calls := calls + 1;
Next := calls;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    c1, c2 : FB_Counter;
    a, b : INT;
END_VAR
a := c1.Next();
b := c2.Next();
END_PROGRAM
