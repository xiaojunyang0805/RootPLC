(* spec: [stdlib.fbs]
   expect: error RP0103 *)
PROGRAM PRG_Main
VAR
    t : TON;
END_VAR
t(IN := TRUE, PT := 500);
END_PROGRAM
