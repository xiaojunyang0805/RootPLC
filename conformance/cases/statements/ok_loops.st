(* spec: [statements.for] [statements.while] [statements.repeat] [statements.control]
   expect: ok
   run: PRG_Main cycles=1
   assert: s = 31
   assert: w = 3
   assert: k = 6 *)
PROGRAM PRG_Main
VAR
    i, s, w, k : INT;
END_VAR
FOR i := 1 TO 10 BY 1 DO
    IF i = 5 THEN
        CONTINUE;
    END_IF
    IF i > 8 THEN
        EXIT;
    END_IF
    s := s + i;
END_FOR
WHILE w < 3 DO
    w := w + 1;
END_WHILE
REPEAT
    k := k + 2;
UNTIL k >= 6
END_REPEAT
RETURN;
END_PROGRAM
