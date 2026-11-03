(* spec: [types.derived.subrange]
   expect: ok
   run: PRG_Main cycles=1
   assert: first = 0
   assert: p = 50 *)
TYPE Percent : INT (0..100); END_TYPE

PROGRAM PRG_Main
VAR
    p : Percent;
    first : INT;
END_VAR
first := p;
p := 50;
END_PROGRAM
