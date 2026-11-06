(* spec: [build.c.command] [build.c.file] [build.c.semantics] [build.c.faults] [build.c.subset] [build.c.oop]
   expect: ok
   run: PRG_Main cycles=5
   assert: n = 5
   assert: wrapped = -32768
   assert: rounded = 3
   assert: total = 15
   assert: avg > 2.99 AND avg < 3.01 *)
(* The v0 subset of the C back end in one program; the driver test
   tests/codegen_c.rs translates it to C, compiles it and compares every
   variable with the VM (with the clock advancing 10 ms per cycle, so the
   timer and counter also run there; the conformance runner does not
   advance the clock). *)
TYPE E_Mode : (IDLE, RUN, DONE); END_TYPE
TYPE ST_Stat : STRUCT
    count : INT;
    sum : DINT;
END_STRUCT; END_TYPE
TYPE T_Pct : INT (0..100); END_TYPE

FUNCTION Average : REAL
VAR_INPUT
    sum : DINT;
    count : INT := 1;
END_VAR
IF count = 0 THEN
    Average := 0.0;
ELSE
    Average := DINT_TO_REAL(sum) / INT_TO_REAL(count);
END_IF;
END_FUNCTION

FUNCTION_BLOCK FB_Acc
VAR_INPUT x : INT; END_VAR
VAR_OUTPUT stat : ST_Stat; END_VAR
stat.count := stat.count + 1;
stat.sum := stat.sum + x;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    n : INT;
    mode : E_Mode := E_Mode#IDLE;
    acc : FB_Acc;
    hist : ARRAY[1..5] OF INT;
    total : DINT;
    avg : REAL;
    wrapped : INT := 32767;
    rounded : DINT;
    pct : T_Pct := 50;
    pulses : CTU;
    blink : TON;
    k : INT;
END_VAR
n := n + 1;
hist[n] := n;
acc(x := n);
total := 0;
FOR k := 1 TO 5 DO
    IF hist[k] = 0 THEN
        CONTINUE;
    END_IF;
    total := total + hist[k];
END_FOR;
avg := Average(sum := acc.stat.sum, count := acc.stat.count);
CASE n OF
    1: mode := E_Mode#RUN;
    2..4: pct := pct + 10;
ELSE
    mode := E_Mode#DONE;
END_CASE;
IF n = 5 THEN
    wrapped := wrapped + 1;
    rounded := REAL_TO_DINT(2.5);
END_IF;
blink(IN := NOT blink.Q, PT := T#20ms);
pulses(CU := blink.Q, PV := 10);
END_PROGRAM
