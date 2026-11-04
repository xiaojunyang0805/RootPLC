(* spec: [types.derived.enum]
   expect: ok
   run: PRG_Main cycles=1
   assert: n = 2
   assert: hit = TRUE
   assert: m = Motor#RUN
   assert: d = Door#OPEN *)
TYPE Motor : (IDLE, RUN, FAULT);
END_TYPE

TYPE Door : (IDLE, OPEN, CLOSED);
END_TYPE

FUNCTION F_Open : BOOL
VAR_INPUT
    d : Door;
END_VAR
F_Open := d = OPEN;
END_FUNCTION

PROGRAM PRG_Main
VAR
    m : Motor := IDLE;     (* initial value: Motor#IDLE *)
    d : Door;
    n : INT;
    hit : BOOL;
END_VAR
IF m = IDLE THEN           (* comparison: the other operand decides *)
    m := RUN;              (* assignment: the target decides *)
END_IF
CASE m OF
    IDLE: n := 1;          (* CASE label: the selector decides *)
    RUN: n := 2;
END_CASE
d := OPEN;
hit := F_Open(IDLE) = FALSE AND F_Open(d);   (* parameter decides *)
END_PROGRAM
