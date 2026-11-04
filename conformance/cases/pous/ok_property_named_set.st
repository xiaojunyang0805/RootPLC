(* spec: [pous.oop.property]
   expect: ok
   run: PRG_Main cycles=1
   assert: v = 2.5 *)
FUNCTION_BLOCK FB_Control
VAR
    fSet : REAL;
END_VAR
PROPERTY Set : REAL
GET
    Set := fSet;
END_GET
SET
    fSet := Set;
END_SET
END_PROPERTY
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    c : FB_Control;
    v : REAL;
END_VAR
c.Set := 2.5;
v := c.Set;
END_PROGRAM
