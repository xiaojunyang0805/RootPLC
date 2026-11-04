(* spec: [pous.call.local-read]
   expect: error RP0203 *)
FUNCTION_BLOCK FB_Plant
VAR
    n : INT;
    arr : ARRAY[0..3] OF INT;
END_VAR
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    fbPlant : FB_Plant;
END_VAR
fbPlant.n := 1;        (* internal variables are read-only from outside *)
fbPlant.arr[1] := 2;
END_PROGRAM
