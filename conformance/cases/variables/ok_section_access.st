(* spec: [variables.section]
   expect: ok
   run: PRG_Main cycles=1
   assert: v = 3 *)
CLASS Counter
VAR PUBLIC RETAIN
    n : INT := 3;
END_VAR
END_CLASS

PROGRAM PRG_Main
VAR
    c : Counter;
    v : INT;
END_VAR
VAR CONSTANT PUBLIC
    k : INT := 0;
END_VAR
v := c.n + k;
END_PROGRAM
