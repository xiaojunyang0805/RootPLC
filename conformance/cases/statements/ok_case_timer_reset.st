(* spec: [statements.case.timer]
   expect: ok *)
(* Three ways to time a step without RP0304. *)
FUNCTION_BLOCK FB_Steps
VAR_INPUT go : BOOL; done : BOOL; END_VAR
VAR
    a : INT;
    b : INT;
    c : INT;
    tA : TON;
    tB : TON;
    tC : TON;
END_VAR
(* every path that leaves the step stops the timer first *)
CASE a OF
    0:
        IF go THEN a := 1; END_IF;
    1:
        tA(IN := TRUE, PT := T#5s);
        IF done OR tA.Q THEN
            tA(IN := FALSE);
            a := 0;
        END_IF;
END_CASE;
(* reset in the step before: cleared before re-entry *)
CASE b OF
    0:
        tB(IN := FALSE);
        IF go THEN b := 1; END_IF;
    1:
        tB(IN := TRUE, PT := T#5s);
        IF tB.Q THEN b := 0; END_IF;
END_CASE;
(* called every cycle outside the CASE with the step condition *)
tC(IN := c = 1, PT := T#5s);
CASE c OF
    0:
        IF go THEN c := 1; END_IF;
    1:
        IF tC.Q THEN c := 0; END_IF;
END_CASE;
END_FUNCTION_BLOCK
