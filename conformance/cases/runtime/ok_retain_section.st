(* spec: [runtime.retain] [variables.section]
   expect: ok *)
(* Counters that survive a restart of the runtime: a RETAIN section of the
   program and of a global variable list. *)
CONFIGURATION Plant
    VAR_GLOBAL RETAIN
        hours : UDINT;
    END_VAR
    RESOURCE Cpu ON PLC
        TASK Main (INTERVAL := T#10ms, PRIORITY := 1);
        PROGRAM Run WITH Main : Counter;
    END_RESOURCE
END_CONFIGURATION

PROGRAM Counter
VAR_EXTERNAL
    hours : UDINT;
END_VAR
VAR RETAIN
    starts : UDINT;
END_VAR
VAR
    btn AT %IX0.0 : BOOL;
    edge : R_TRIG;
END_VAR
edge(CLK := btn);
IF edge.Q THEN
    starts := starts + 1;
END_IF;
END_PROGRAM
