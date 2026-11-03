(* spec: [pous.action]
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 3
   assert: m = 10 *)
FUNCTION_BLOCK FB_Counter
VAR_OUTPUT
    count : INT;
END_VAR
ACTION Reset:
    count := 0;
END_ACTION
ACTION Advance:
    count := count + 1;
END_ACTION
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_Tank
VAR_OUTPUT
    level : INT;
END_VAR
END_FUNCTION_BLOCK

ACTION Fill:
    level := 10;
END_ACTION

PROGRAM PRG_Main
VAR
    c : FB_Counter;
    t : FB_Tank;
    n, m : INT;
END_VAR
c.Advance();
c.Advance();
c.Reset();
c.Advance();
c.Advance();
c.Advance();
n := c.count;
t.Fill();
m := t.level;
END_PROGRAM
