(* spec: [pous.oop.interface-ref]
   expect: ok
   run: PRG_Main cycles=1
   assert: total = 14
   assert: empty
   assert: set *)
INTERFACE I_Shape
METHOD Area : INT
END_METHOD
END_INTERFACE

FUNCTION_BLOCK FB_Square IMPLEMENTS I_Shape
VAR_INPUT
    side : INT := 2;
END_VAR
METHOD Area : INT
Area := side * side;
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Rect IMPLEMENTS I_Shape
VAR_INPUT
    w : INT := 2;
    h : INT := 5;
END_VAR
METHOD Area : INT
Area := w * h;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    sq : FB_Square;
    re : FB_Rect;
    shapes : ARRAY[1..2] OF I_Shape;
    none : I_Shape;
    i, total : INT;
    empty, set : BOOL;
END_VAR
shapes[1] := sq;
shapes[2] := re;
FOR i := 1 TO 2 DO
    total := total + shapes[i].Area();
END_FOR;
empty := none = NULL;
set := shapes[1] <> NULL;
END_PROGRAM
