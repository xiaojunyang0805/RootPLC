(* spec: [lexical.comment.nesting]
   expect: warning RP0003 *)
PROGRAM PRG_Main
VAR
    x : INT;
END_VAR
(* outer (* inner *)
x := 1;
END_PROGRAM
