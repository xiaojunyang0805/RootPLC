(* spec: [pous.oop.extends]
   expect: ok
   run: PRG_Main cycles=2
   assert: base_count = 2
   assert: own_count = 2 *)
FUNCTION_BLOCK FB_Counter
VAR_OUTPUT
    count : INT;
END_VAR
count := count + 1;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Pair EXTENDS FB_Counter
VAR_OUTPUT
    mine : INT;
END_VAR
SUPER^();
mine := mine + 1;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    p : FB_Pair;
    base_count, own_count : INT;
END_VAR
p();
base_count := p.count;
own_count := p.mine;
END_PROGRAM
