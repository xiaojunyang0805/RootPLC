(* spec: [pous.oop.class]
   expect: ok
   run: PRG_Main cycles=1
   assert: v = 6 *)
CLASS Accumulator
VAR
    sum : INT;
END_VAR
METHOD PUBLIC Add : INT
VAR_INPUT
    x : INT;
END_VAR
sum := sum + x;
Add := sum;
END_METHOD
END_CLASS

PROGRAM PRG_Main
VAR
    acc : Accumulator;
    v : INT;
END_VAR
acc.Add(x := 1);
acc.Add(x := 2);
v := acc.Add(x := 3);
END_PROGRAM
