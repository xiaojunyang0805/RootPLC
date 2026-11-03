(* spec: [pous.oop.property]
   expect: ok *)
FUNCTION_BLOCK FB_Valve
VAR
    pos : INT;
END_VAR
PROPERTY Position : INT
GET
    Position := pos;
END_GET
SET
    pos := Position;
END_SET
END_PROPERTY
END_FUNCTION_BLOCK
