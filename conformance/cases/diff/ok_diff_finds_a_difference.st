(* spec: [diff.compare] [diff.report] [diff.stimuli]
   expect: ok *)
(* A latch where start wins over stop, compared with a reference where stop
   wins: rootplc diff --reference FB_StopWins --unit FB_StartWins reports a
   difference on Out in the cycle where Start and a stop come together
   (crates/rootplc-driver/tests/diff.rs). With --set StopOk=TRUE the
   difference cannot occur and the blocks agree. *)
FUNCTION_BLOCK FB_StopWins
VAR_INPUT
    Start  : BOOL;
    StopOk : BOOL;
    Delay  : TIME := T#1s;
END_VAR
VAR_OUTPUT
    Out   : BOOL;
    Since : TIME;
END_VAR
VAR
    t : TON;
END_VAR
IF NOT StopOk THEN
    Out := FALSE;
ELSIF Start THEN
    Out := TRUE;
END_IF;
t(IN := Out, PT := Delay);
Since := t.ET;
END_FUNCTION_BLOCK

FUNCTION_BLOCK FB_StartWins
VAR_INPUT
    Start  : BOOL;
    StopOk : BOOL;
    Delay  : TIME := T#1s;
END_VAR
VAR_OUTPUT
    Out   : BOOL;
    Since : TIME;
END_VAR
VAR
    t : TON;
END_VAR
IF Start THEN
    Out := TRUE;
ELSIF NOT StopOk THEN
    Out := FALSE;
END_IF;
t(IN := Out, PT := Delay);
Since := t.ET;
END_FUNCTION_BLOCK
