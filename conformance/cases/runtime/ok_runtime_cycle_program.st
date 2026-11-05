(* spec: [runtime.cycle] [runtime.watchdog] [runtime.status]
   expect: ok
   run: Blink cycles=50 *)
(* A program as the runtime runs it: inputs and outputs are located, one
   call per cycle, time from the cycle clock. Under the runtime a fault in a
   cycle (here none) would stop it with safe outputs. *)
PROGRAM Blink
VAR
    lamp AT %QX0.0 : BOOL;
    t : TON;
    n : INT;
END_VAR
t(IN := NOT t.Q, PT := T#100ms);
IF t.Q THEN
    lamp := NOT lamp;
    n := n + 1;
END_IF;
END_PROGRAM
