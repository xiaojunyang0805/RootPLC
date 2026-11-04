(* spec: [pous.call.local-read]
   expect: warning RP0130
   run: PRG_Main cycles=1
   assert: a = 3
   assert: b = 4
   assert: c = 30
   assert: d = 7 *)
FUNCTION_BLOCK FB_Inner
VAR
    nCount : INT := 3;
END_VAR
METHOD Bump : INT
nCount := nCount + 1;
Bump := nCount;
END_METHOD
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Plant
VAR
    fbInner : FB_Inner;
    arr : ARRAY[0..3] OF INT := [10, 20, 30, 40];
END_VAR
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    fbPlant : FB_Plant;
    a, b, c, d : INT;
    out : ARRAY[0..5] OF INT;
END_VAR
a := fbPlant.fbInner.nCount;        (* read an internal variable *)
b := fbPlant.fbInner.Bump();        (* call a method of an internal instance *)
c := fbPlant.arr[2];                (* read an element of an internal array *)
out[fbPlant.fbInner.nCount] := 7;   (* a read inside an assignment target *)
d := out[4];
END_PROGRAM
