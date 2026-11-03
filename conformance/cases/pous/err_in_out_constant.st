(* spec: [pous.call.in-out]
   expect: error RP0114 *)
FUNCTION AddTo : BOOL
VAR_IN_OUT
    acc : INT;
END_VAR
acc := acc + 1;
AddTo := TRUE;
END_FUNCTION

PROGRAM PRG_Main
VAR
    ok : BOOL;
END_VAR
ok := AddTo(acc := 5);
END_PROGRAM
