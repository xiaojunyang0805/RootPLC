(* spec: [diff.command] [diff.interface] [diff.stimuli] [diff.compare] [diff.report] [diff.limits]
   expect: ok *)
(* A reference start/stop latch and a block written another way, with
   other names, wrapped in an adapter that has the reference's names.
   rootplc diff --reference FB_RefLatch --unit FB_LatchAdapter agrees
   (crates/rootplc-driver/tests/diff.rs). *)
FUNCTION_BLOCK FB_RefLatch
VAR_INPUT
    Start  : BOOL;
    StopOk : BOOL;                 (* FALSE stops; stop wins *)
    Limit  : REAL;
    Level  : REAL;
END_VAR
VAR_OUTPUT
    Out  : BOOL;
    High : BOOL;                   (* Level above Limit *)
END_VAR
IF NOT StopOk THEN
    Out := FALSE;
ELSIF Start THEN
    Out := TRUE;
END_IF;
High := Level > Limit;
END_FUNCTION_BLOCK

(* the block from a real project: other names, other style *)
FUNCTION_BLOCK FB_PumpLatch
VAR_INPUT
    xStart     : BOOL;
    xStopNC    : BOOL;
    rThreshold : REAL;
    rValue     : REAL;
END_VAR
VAR_OUTPUT
    xRun   : BOOL;
    xAlarm : BOOL;
END_VAR
VAR
    latch : RS;
END_VAR
latch(S := xStart, R1 := NOT xStopNC);
xRun := latch.Q1;
xAlarm := NOT (rValue <= rThreshold);
END_FUNCTION_BLOCK

(* the adapter: the reference's names around the real block *)
FUNCTION_BLOCK FB_LatchAdapter
VAR_INPUT
    Start  : BOOL;
    StopOk : BOOL;
    Limit  : REAL;
    Level  : REAL;
END_VAR
VAR_OUTPUT
    Out  : BOOL;
    High : BOOL;
END_VAR
VAR
    wrapped : FB_PumpLatch;
END_VAR
wrapped(xStart := Start, xStopNC := StopOk, rThreshold := Limit, rValue := Level);
Out := wrapped.xRun;
High := wrapped.xAlarm;
END_FUNCTION_BLOCK
