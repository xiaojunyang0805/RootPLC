(* spec: [pous.call.in-out]
   expect: ok
   run: PRG_Main cycles=2
   assert: total = 10
   assert: count = 2
   assert: arr[2] = 4 *)
FUNCTION AddTo : BOOL
VAR_IN_OUT
    acc : INT;
END_VAR
VAR_INPUT
    n : INT;
END_VAR
acc := acc + n;
AddTo := TRUE;
END_FUNCTION

FUNCTION_BLOCK FB_Count
VAR_IN_OUT
    c : INT;
END_VAR
c := c + 1;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    total, count : INT;
    arr : ARRAY[1..3] OF INT;
    ok : BOOL;
    fb : FB_Count;
END_VAR
ok := AddTo(acc := total, n := 5);
fb(c := count);
ok := AddTo(arr[2], 2);
END_PROGRAM
