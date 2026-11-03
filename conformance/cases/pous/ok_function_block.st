(* spec: [pous.function] [pous.function-block] [statements.call] [statements.assignment]
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 1
   assert: y = 10 *)
FUNCTION Clamp : INT
VAR_INPUT
    v, lo, hi : INT;
END_VAR
IF v < lo THEN
    Clamp := lo;
ELSIF v > hi THEN
    Clamp := hi;
ELSE
    Clamp := v;
END_IF
END_FUNCTION

FUNCTION_BLOCK FB_Counter
VAR_INPUT
    pulse : BOOL;
END_VAR
VAR_OUTPUT
    count : INT;
END_VAR
IF pulse THEN
    count := count + 1;
END_IF
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    c : FB_Counter;
    n : INT;
    y : INT;
END_VAR
c(pulse := TRUE, count => n);
y := Clamp(15, 0, 10);
END_PROGRAM
