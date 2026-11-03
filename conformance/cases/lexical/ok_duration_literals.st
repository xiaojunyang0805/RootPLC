(* spec: [lexical.literal.duration]
   expect: ok
   run: PRG_Main cycles=1
   assert: t1 = T#90m
   assert: t3 = T#1500ms *)
PROGRAM PRG_Main
VAR
    t1 : TIME := T#1h_30m;
    t2 : TIME := T#90m;
    t3 : TIME := T#1.5s;
    t4 : LTIME := LTIME#5us;
    t5 : TIME := t#-250ms;
END_VAR

END_PROGRAM
