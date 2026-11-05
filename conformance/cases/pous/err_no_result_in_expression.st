(* spec: [pous.oop.method] [pous.function]
   expect: error RP0303 *)
(* A method without a result type has no value (found in a corpus block
   that assigned such a call; vendor compilers reject it). *)
FUNCTION_BLOCK FB_Buffer
VAR size : UDINT := 100; END_VAR
METHOD SetSize
VAR_INPUT n : UDINT; END_VAR
size := n;
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    b : FB_Buffer;
    n : UDINT := 32;
END_VAR
b.SetSize(n);
n := b.SetSize(n);
END_PROGRAM
