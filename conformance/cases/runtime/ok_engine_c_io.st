(* spec: [build.c.abi] [build.c.shim] [runtime.engine] [runtime.image]
   expect: ok *)
(* Located inputs, outputs and memory, a RETAIN counter and a timer:
   crates/rootplc-driver/tests/engine_c.rs runs this program on the VM
   engine, the C engine (rootplc runtime --engine c) and the C runtime
   (runtime-c, POSIX port) under the same virtual clock and inputs, and
   compares the variables and the output image. *)
PROGRAM PRG_Io
VAR
    start AT %IX0.0 : BOOL;
    level AT %IW2 : INT;
    lamp AT %QX0.1 : BOOL;
    speed AT %QW2 : INT;
    hold AT %MD4 : REAL;
    count : DINT;
    blink : TON;
    tally AT %QB4 : USINT;
END_VAR
VAR RETAIN
    starts : UDINT;
END_VAR
count := count + 1;
lamp := start AND NOT blink.Q;
blink(IN := start AND NOT blink.Q, PT := T#30ms);
IF blink.Q THEN
    starts := starts + 1;
END_IF;
speed := level * 2;
hold := INT_TO_REAL(level) / 3.0;
tally := DINT_TO_USINT(count);
END_PROGRAM
