(* spec: [pous.end]
   expect: warning RP0131 *)
(* a CODESYS object export: the program has no END_PROGRAM; the end of
   the file closes it *)
PROGRAM PRG_Main
VAR
    n : INT;
END_VAR
n := n + 1;
