(* spec: [pous.oop.method]
   expect: ok
   run: PRG_Main cycles=1
   assert: total = 7
   assert: r = 14 *)
FUNCTION_BLOCK FB_Acc
VAR
    sum : INT;
END_VAR
METHOD Add : INT
VAR_INPUT
    amount : INT;
END_VAR
sum := sum + amount;
Add := sum;
END_METHOD
METHOD Double : INT
Double := Add(amount := sum);
END_METHOD
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    acc : FB_Acc;
    total, r : INT;
END_VAR
acc.Add(amount := 3);
total := acc.Add(amount := 4);
r := acc.Double();
END_PROGRAM
