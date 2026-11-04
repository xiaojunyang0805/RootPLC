(* spec: [pous.oop.property] [scope.vendor-forms]
   expect: warning RP0134
   run: PRG_Main cycles=1
   assert: a = 40
   assert: b = 50
   assert: c = 7
   assert: d = 14 *)
INTERFACE I_Level
PROPERTY Level : INT
GET
END_GET
END_PROPERTY
END_INTERFACE

FUNCTION_BLOCK FB_Valve IMPLEMENTS I_Level
VAR
    pos : INT;
END_VAR
PROPERTY Position : INT
GET
    Position := pos;
END_GET
SET
    pos := LIMIT(0, Position, 100);
END_SET
END_PROPERTY
PROPERTY Level : INT
GET
    Level := pos;
END_GET
END_PROPERTY
METHOD Open
Position := Position + 10;
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Doubler EXTENDS FB_Valve
PROPERTY Level : INT
GET
    Level := SUPER^.Level * 2;
END_GET
END_PROPERTY
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    v : FB_Valve;
    w : FB_Doubler;
    itf : I_Level;
    a, b, c, d : INT;
END_VAR
v.Position := 30;
v.Open();
a := v.Position;
v.Position := v.Position + 10;
b := v.Level;
w.Position := 7;
itf := w;
c := w.Position;
d := itf.Level;
END_PROGRAM
