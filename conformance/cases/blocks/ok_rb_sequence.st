(* spec: [blocks.command] [blocks.fault] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_StepChain (F05.STEPS) and RB_Phase (F05.PHASE). *)

(* the pattern the card shows: the chain, then the actions per step *)
FUNCTION_BLOCK FillCycle
VAR_INPUT
    start  : BOOL;
    full   : BOOL;
    empty  : BOOL;
END_VAR
VAR_OUTPUT
    inlet  : BOOL;
    outlet : BOOL;
    fills  : INT;
END_VAR
VAR
    chain : RB_StepChain;
END_VAR
CASE chain.StepNo OF
1: chain(Start := start, Proceed := full, LastStep := 2, StepTimeout := T#5s);
2: chain(Start := start, Proceed := empty, LastStep := 2, StepTimeout := T#5s);
ELSE
    chain(Start := start, Proceed := FALSE, LastStep := 2, StepTimeout := T#5s);
END_CASE;
inlet := chain.StepNo = 1;
outlet := chain.StepNo = 2;
IF chain.FirstCall AND chain.StepNo = 1 THEN
    fills := fills + 1;
END_IF;
END_FUNCTION_BLOCK

TEST chain_runs_its_steps_in_order
VAR f : FillCycle; END_VAR
f(start := FALSE);
ASSERT_EQ(0, f.chain.StepNo);
ASSERT_FALSE(f.chain.Busy);
f(start := TRUE);
ASSERT_EQ(1, f.chain.StepNo);
ASSERT_TRUE(f.inlet);
ASSERT_TRUE(f.chain.FirstCall);
ASSERT_TRUE(f.chain.Busy);
ASSERT_EQ(1, f.fills);
f(start := TRUE);
ASSERT_FALSE(f.chain.FirstCall);
ASSERT_EQ(1, f.fills);
f(start := TRUE, full := TRUE);
ASSERT_EQ(2, f.chain.StepNo);
ASSERT_TRUE(f.chain.FirstCall);
ASSERT_TRUE(f.outlet);
f(start := TRUE, full := TRUE, empty := TRUE);
ASSERT_EQ(0, f.chain.StepNo);
ASSERT_TRUE(f.chain.Done);
ASSERT_FALSE(f.chain.Busy);
f(start := TRUE, full := TRUE, empty := TRUE);
ASSERT_FALSE(f.chain.Done);
ASSERT_EQ(0, f.chain.StepNo);
(* a new rising edge starts it again *)
f(start := FALSE);
f(start := TRUE);
ASSERT_EQ(1, f.chain.StepNo);
ASSERT_EQ(2, f.fills);
END_TEST

TEST chain_step_time_and_timeout
VAR c : RB_StepChain; END_VAR
c(Start := TRUE, LastStep := 3, StepTimeout := T#2s);
ADVANCE(T#1500ms);
c(Start := TRUE, LastStep := 3, StepTimeout := T#2s);
ASSERT_TRUE(c.StepTime = T#1500ms);
ASSERT_FALSE(c.Error);
ADVANCE(T#500ms);
c(Start := TRUE, LastStep := 3, StepTimeout := T#2s);
ASSERT_TRUE(c.Error);
ASSERT_EQ(UDINT#1, c.ErrorID);
ASSERT_EQ(1, c.StepNo);
(* the fault holds the chain: Proceed is ignored *)
c(Start := TRUE, Proceed := TRUE, LastStep := 3, StepTimeout := T#2s);
ASSERT_EQ(1, c.StepNo);
(* reset restarts the step timer *)
c(Start := TRUE, Proceed := FALSE, LastStep := 3, StepTimeout := T#2s, Reset := TRUE);
ASSERT_FALSE(c.Error);
ASSERT_EQ(UDINT#0, c.ErrorID);
ASSERT_TRUE(c.StepTime = T#0s);
ADVANCE(T#1s);
c(Start := TRUE, Proceed := TRUE, LastStep := 3, StepTimeout := T#2s, Reset := FALSE);
ASSERT_EQ(2, c.StepNo);
ASSERT_TRUE(c.StepTime = T#0s);
(* no timeout configured: no fault *)
ADVANCE(T#1h);
c(Start := TRUE, Proceed := FALSE, LastStep := 3, StepTimeout := T#0s);
ASSERT_FALSE(c.Error);
END_TEST

TEST chain_hold_pauses_and_abort_resets
VAR c : RB_StepChain; END_VAR
c(Start := TRUE, LastStep := 2, StepTimeout := T#2s);
ADVANCE(T#1s);
c(Start := TRUE, Hold := TRUE, Proceed := TRUE, LastStep := 2, StepTimeout := T#2s);
ASSERT_EQ(1, c.StepNo);
ASSERT_TRUE(c.Held);
ADVANCE(T#10s);
c(Start := TRUE, Hold := TRUE, Proceed := FALSE, LastStep := 2, StepTimeout := T#2s);
ASSERT_FALSE(c.Error);
ASSERT_TRUE(c.StepTime = T#0s);
c(Start := TRUE, Hold := FALSE, Proceed := FALSE, LastStep := 2, StepTimeout := T#2s);
ASSERT_FALSE(c.Held);
ASSERT_FALSE(c.Error);
c(Start := TRUE, Abort := TRUE, LastStep := 2, StepTimeout := T#2s);
ASSERT_EQ(0, c.StepNo);
ASSERT_TRUE(c.Aborted);
ASSERT_FALSE(c.Busy);
ASSERT_FALSE(c.Held);
c(Start := TRUE, Abort := TRUE, LastStep := 2, StepTimeout := T#2s);
ASSERT_FALSE(c.Aborted);
(* while Abort is TRUE the chain does not start *)
c(Start := FALSE, Abort := TRUE, LastStep := 2);
c(Start := TRUE, Abort := TRUE, LastStep := 2);
ASSERT_EQ(0, c.StepNo);
END_TEST

TEST chain_branches_with_next_step
VAR c : RB_StepChain; END_VAR
c(Start := TRUE, LastStep := 5);
c(Start := TRUE, Proceed := TRUE, NextStep := 4, LastStep := 5);
ASSERT_EQ(4, c.StepNo);
ASSERT_TRUE(c.FirstCall);
c(Start := TRUE, Proceed := TRUE, NextStep := 0, LastStep := 5);
ASSERT_EQ(5, c.StepNo);
(* a jump back from the last step keeps the chain running *)
c(Start := TRUE, Proceed := TRUE, NextStep := 2, LastStep := 5);
ASSERT_EQ(2, c.StepNo);
ASSERT_FALSE(c.Done);
(* an abort with an active timeout fault clears it *)
c(Start := TRUE, Proceed := FALSE, StepTimeout := T#1s, LastStep := 5);
ADVANCE(T#2s);
c(Start := TRUE, Proceed := FALSE, StepTimeout := T#1s, LastStep := 5);
ASSERT_TRUE(c.Error);
c(Start := TRUE, Abort := TRUE, LastStep := 5);
ASSERT_FALSE(c.Error);
ASSERT_EQ(UDINT#0, c.ErrorID);
END_TEST

TEST phase_runs_holds_and_completes
VAR p : RB_Phase; END_VAR
p();
ASSERT_TRUE(p.State = RB_PHASE_STATE#Idle);
p(Start := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Running);
ASSERT_TRUE(p.Running);
ASSERT_FALSE(p.Rejected);
p(Start := FALSE, Hold := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Held);
ASSERT_FALSE(p.Running);
p(Hold := FALSE, Finished := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Held);
p(Restart := TRUE, Finished := FALSE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Running);
p(Restart := FALSE, Finished := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Complete);
ASSERT_TRUE(p.Done);
p(Finished := FALSE, Reset := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Idle);
ASSERT_FALSE(p.Done);
END_TEST

TEST phase_stop_abort_and_rejected_commands
VAR p : RB_Phase; END_VAR
(* commands that do not fit the state are rejected *)
p(Hold := TRUE);
ASSERT_TRUE(p.Rejected);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Idle);
p(Hold := FALSE, Restart := TRUE);
ASSERT_TRUE(p.Rejected);
p(Restart := FALSE, Stop := TRUE);
ASSERT_TRUE(p.Rejected);
p(Stop := FALSE, Abort := TRUE);
ASSERT_TRUE(p.Rejected);
p(Abort := FALSE, Reset := TRUE);
ASSERT_TRUE(p.Rejected);
p(Reset := FALSE);
ASSERT_FALSE(p.Rejected);
p(Start := TRUE);
ASSERT_FALSE(p.Rejected);
p(Start := FALSE);
p(Start := TRUE);
ASSERT_TRUE(p.Rejected);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Running);
(* stop from running, abort from stopped, reset from aborted *)
p(Start := FALSE, Stop := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Stopped);
p(Stop := FALSE, Abort := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Aborted);
p(Abort := FALSE, Stop := TRUE);
ASSERT_TRUE(p.Rejected);
p(Stop := FALSE, Reset := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Idle);
(* stop and abort from held; reset from stopped *)
p(Reset := FALSE, Start := TRUE);
p(Start := FALSE, Hold := TRUE);
p(Hold := FALSE, Stop := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Stopped);
p(Stop := FALSE, Reset := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Idle);
p(Reset := FALSE, Start := TRUE);
p(Start := FALSE, Hold := TRUE);
p(Hold := FALSE, Abort := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Aborted);
(* abort from running; completed phases reject stop *)
p(Abort := FALSE, Reset := TRUE);
p(Reset := FALSE, Start := TRUE);
p(Start := FALSE, Abort := TRUE);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Aborted);
p(Abort := FALSE, Reset := TRUE);
p(Reset := FALSE, Start := TRUE);
p(Start := FALSE, Finished := TRUE);
p(Finished := FALSE, Stop := TRUE);
ASSERT_TRUE(p.Rejected);
ASSERT_TRUE(p.State = RB_PHASE_STATE#Complete);
p(Stop := FALSE, Abort := TRUE);
ASSERT_TRUE(p.Rejected);
p(Abort := FALSE, Hold := TRUE);
ASSERT_TRUE(p.Rejected);
END_TEST
