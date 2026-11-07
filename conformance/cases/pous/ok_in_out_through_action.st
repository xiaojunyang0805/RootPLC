(* spec: [pous.call.in-out]
   expect: ok
   run: PRG_Main cycles=1
   assert: first = 1
   assert: second = 2
   assert: seen = 2 *)
TYPE ST_Steps :
STRUCT
    list : ARRAY[0..3] OF INT;
END_STRUCT;
END_TYPE

(* the action writes the block's VAR_IN_OUT: the caller's variable *)
FUNCTION_BLOCK StepFb
VAR_INPUT
    k : INT;
END_VAR
VAR_IN_OUT
    st : ST_Steps;
END_VAR
VAR_OUTPUT
    seen : INT;
END_VAR
Register();
seen := st.list[2];

ACTION Register:
st.list[k] := k;
END_ACTION
END_FUNCTION_BLOCK

FUNCTION_BLOCK Chain
VAR_IN_OUT
    st : ST_Steps;
END_VAR
VAR
    a, b : StepFb;
END_VAR
VAR_OUTPUT
    seen : INT;
END_VAR
a(k := 1, st := st);
b(k := 2, st := st);
seen := a.seen;
END_FUNCTION_BLOCK

PROGRAM PRG_Main
VAR
    c : Chain;
    s : ST_Steps;
    first, second, seen : INT;
END_VAR
c(st := s);
c(st := s);
first := s.list[1];
second := s.list[2];
seen := c.seen;
END_PROGRAM
