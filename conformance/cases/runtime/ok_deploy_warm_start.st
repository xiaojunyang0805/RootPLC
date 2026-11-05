(* spec: [runtime.deploy] [runtime.retain]
   expect: ok *)
(* Version 2 of a counter program, as it would be deployed over version 1:
   `total` (RETAIN, same name and type) keeps its value across the swap;
   `rate` is new and starts from its initial value. *)
PROGRAM Counter
VAR RETAIN
    total : UDINT;
END_VAR
VAR
    btn AT %IX0.0 : BOOL;
    edge : R_TRIG;
    rate : UINT := 1;
END_VAR
edge(CLK := btn);
IF edge.Q THEN
    total := total + UINT_TO_UDINT(rate);
END_IF;
END_PROGRAM
