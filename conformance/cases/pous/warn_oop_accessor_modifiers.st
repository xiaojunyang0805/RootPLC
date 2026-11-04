(* spec: [pous.oop.modifiers] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=1
   assert: x = 9 *)
FUNCTION_BLOCK FB_Store
VAR
    v : INT := 4;
END_VAR
PROPERTY PUBLIC Value : INT
GET PUBLIC
    Value := v;
END_GET
SET PROTECTED
    v := Value;
END_SET
END_PROPERTY
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    f : FB_Store;
    x : INT;
END_VAR
f.Value := 9;
x := f.Value;
END_PROGRAM
