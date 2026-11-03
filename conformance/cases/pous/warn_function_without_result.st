(* spec: [pous.function]
   expect: warning RP0113
   run: PRG_Main cycles=2
   assert: total = 10 *)
FUNCTION AddTo
VAR_IN_OUT
    acc : INT;
END_VAR
VAR_INPUT
    n : INT;
END_VAR
acc := acc + n;
END_FUNCTION

PROGRAM PRG_Main
VAR
    total : INT;
END_VAR
AddTo(acc := total, n := 5);
END_PROGRAM
