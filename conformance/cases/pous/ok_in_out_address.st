(* spec: [pous.call.in-out]
   expect: ok
   run: PRG_Main cycles=1
   assert: seen = 42
   assert: value = 43 *)
FUNCTION AddressOf : REF_TO INT
VAR_IN_OUT
    x : INT;
END_VAR
AddressOf := REF(x);
END_FUNCTION

PROGRAM PRG_Main
VAR
    value : INT := 42;
    p : REF_TO INT;
    seen : INT;
END_VAR
p := AddressOf(value);
seen := p^;
p^ := 43;
END_PROGRAM
