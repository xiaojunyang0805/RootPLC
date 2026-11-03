(* spec: [types.derived.alias] [types.equivalence]
   expect: ok
   run: PRG_Main cycles=1
   assert: i = 10
   assert: s = 11 *)
TYPE Speed : INT := 10; END_TYPE

PROGRAM PRG_Main
VAR
    s : Speed;
    i : INT;
END_VAR
i := s;
s := i + 1;
END_PROGRAM
