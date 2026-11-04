(* spec: [pous.oop.interface-ref] [scope.vendor-forms]
   expect: warning RP0127
   run: PRG_Main cycles=1
   assert: a = TRUE
   assert: b = TRUE
   assert: c = 5 *)
INTERFACE I_Value
METHOD Get : INT
END_METHOD
END_INTERFACE

FUNCTION_BLOCK FB_Five IMPLEMENTS I_Value
METHOD Get : INT
Get := 5;
END_METHOD
END_FUNCTION_BLOCK

FUNCTION F_Read : INT
VAR_INPUT
    ip : I_Value := 0;
END_VAR
IF ip <> 0 THEN
    F_Read := ip.Get();
END_IF;
END_FUNCTION

PROGRAM PRG_Main
VAR
    ipA : I_Value := 0;
    ipB : I_Value := NULL;
    five : FB_Five;
    a, b : BOOL;
    c : INT;
END_VAR
a := ipA = 0;
b := ipB = NULL AND F_Read() = 0;
c := F_Read(five);
END_PROGRAM
