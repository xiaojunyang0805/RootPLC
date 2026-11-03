(* spec: [stdlib.fbs]
   expect: ok *)
PROGRAM PRG_Main
VAR
    start, stop : BOOL;
    t : TON;
    edge : R_TRIG;
    cnt : CTU;
    latch : SR;
    count : INT;
    elapsed : TIME;
END_VAR
t(IN := start, PT := T#2s, ET => elapsed);
edge(CLK := start);
cnt(CU := edge.Q, R := stop, PV := 10);
count := cnt.CV;
latch(S1 := t.Q, R := stop);
END_PROGRAM
