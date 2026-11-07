(* spec: [pous.call.in-out]
   expect: ok
   run: PRG_Main cycles=1
   assert: viaFb = 2
   assert: viaFun = 3
   assert: seen = 3
   assert: shown = 2 *)
(* The counter keeps a pointer into itself; passed as VAR_IN_OUT, the
   write through that pointer and the parameter are one variable. *)
FUNCTION_BLOCK Counter
VAR_OUTPUT
    v : INT;
END_VAR
VAR
    p : REF_TO INT;
END_VAR
IF p = NULL THEN
    p := REF(v);
END_IF;
p^ := p^ + 1;
END_FUNCTION_BLOCK

FUNCTION_BLOCK Bump
VAR_IN_OUT
    c : Counter;
END_VAR
VAR_OUTPUT
    seen : INT;
END_VAR
c();
seen := c.v;
END_FUNCTION_BLOCK

FUNCTION BumpF : INT
VAR_IN_OUT
    c : Counter;
END_VAR
c();
BumpF := c.v;
END_FUNCTION

PROGRAM PRG_Main
VAR
    cnt : Counter;
    b : Bump;
    viaFb, viaFun, seen, shown : INT;
END_VAR
cnt();
b(c := cnt);
viaFb := cnt.v;
shown := b.seen;
seen := BumpF(cnt);
viaFun := cnt.v;
END_PROGRAM
