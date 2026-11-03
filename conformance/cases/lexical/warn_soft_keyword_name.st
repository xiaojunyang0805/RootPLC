(* spec: [lexical.keywords.soft]
   expect: warning RP0124
   run: PRG_Main cycles=2
   assert: n = 2
   assert: lit = TRUE *)
FUNCTION_BLOCK FB_Sequence
VAR_INPUT
    Step : INT;
    On : BOOL;
END_VAR
VAR_OUTPUT
    Task : DINT;
END_VAR
CASE Step OF
    1: Task := Task + 1;
END_CASE
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    seq : FB_Sequence;
    n : DINT;
    lit : BOOL;
    lamp AT %QX0.0 : BOOL;
END_VAR
seq(Step := 1, On := TRUE);
n := seq.Task;
lamp := seq.On;
lit := lamp;
END_PROGRAM
