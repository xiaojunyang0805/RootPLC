(* spec: [types.derived.enum]
   expect: warning RP0122
   run: PRG_Main cycles=1
   assert: x = 2 *)
TYPE E_Step : (Idle, Moving, Done); END_TYPE

PROGRAM PRG_Main
VAR
    s : E_Step := E_Step#Moving;
    x : INT;
END_VAR
CASE s OF
    E_Step.Idle:
        x := 1;
    E_Step.Moving, E_Step.Done:
        x := 2;
ELSE
    x := 3;
END_CASE;
END_PROGRAM
