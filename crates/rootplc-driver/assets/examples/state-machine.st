(* title: State machine with an enumeration and CASE
   tags: state machine, sequence, CASE, enum, step
   description: A three-step sequence (idle, running, done) written as an enumeration and a CASE statement; the pattern for any step sequence. *)
TYPE E_Step : (Idle, Running, Done); END_TYPE

FUNCTION_BLOCK EX_Sequence
VAR_INPUT
    go, finished, ack : BOOL;
END_VAR
VAR_OUTPUT
    state : E_Step;
    busy : BOOL;
END_VAR
CASE state OF
    E_Step#Idle:
        IF go THEN state := E_Step#Running; END_IF
    E_Step#Running:
        IF finished THEN state := E_Step#Done; END_IF
    E_Step#Done:
        IF ack THEN state := E_Step#Idle; END_IF
END_CASE
busy := state = E_Step#Running;
END_FUNCTION_BLOCK

TEST ex_sequence_steps
VAR uut : EX_Sequence; END_VAR
uut(go := TRUE);
ASSERT_TRUE(uut.busy);
uut(go := FALSE, finished := TRUE);
ASSERT_TRUE(uut.state = E_Step#Done);
uut(finished := FALSE, ack := TRUE);
ASSERT_TRUE(uut.state = E_Step#Idle);
END_TEST
