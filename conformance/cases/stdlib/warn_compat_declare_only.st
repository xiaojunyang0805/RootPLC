(* spec: [stdlib.compat.declare-only]
   libraries: Tc2_System
   expect: warning RP0120
   run: PRG_Main cycles=1
   assert: x = 0.0 *)
PROGRAM PRG_Main
VAR
    draw : BOOL;
    rnd : DRAND;
    x : LREAL;
END_VAR
IF draw THEN
    rnd(Seed := 1);
    x := rnd.Num;
END_IF;
END_PROGRAM
