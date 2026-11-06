(* spec: [types.derived.array]
   expect: error RP0103 *)
(* Only arrays (and, as vendor forms, strings and references) can be
   indexed. *)
PROGRAM PRG_Main
VAR
    x : INT;
    y : INT;
END_VAR
y := x[0];
END_PROGRAM
