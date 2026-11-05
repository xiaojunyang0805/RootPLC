(* spec: [blocks.mode] [blocks.command] [blocks.testable]
   expect: ok
   libraries: RootBlocks *)
(* Test suites of RB_ModeManager (F10.MODES), RB_MachineState (F10.STATE)
   and RB_Counter (F03.COUNTER). Every call passes the inputs that matter:
   block inputs keep their last value. *)
TEST modes_requests_and_permissions
VAR m : RB_ModeManager; END_VAR
m();
ASSERT_TRUE(m.Mode = RB_MODE#Off);
ASSERT_FALSE(m.ModeChanged);
m(ReqManual := TRUE);
ASSERT_TRUE(m.Mode = RB_MODE#Manual);
ASSERT_TRUE(m.ModeChanged);
ASSERT_FALSE(m.Rejected);
m(ReqManual := FALSE, ReqAuto := TRUE);
ASSERT_TRUE(m.Mode = RB_MODE#Auto);
m(ReqAuto := FALSE);
ASSERT_FALSE(m.ModeChanged);
m(ReqOff := TRUE);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
(* Auto not allowed: rejected *)
m(ReqOff := FALSE, ReqAuto := TRUE, AutoAllowed := FALSE);
ASSERT_TRUE(m.Rejected);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
m(ReqAuto := FALSE, AutoAllowed := TRUE);
ASSERT_FALSE(m.Rejected);
(* a fault rejects Auto *)
m(ReqAuto := TRUE, Fault := TRUE);
ASSERT_TRUE(m.Rejected);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
(* Manual not allowed *)
m(ReqAuto := FALSE, Fault := FALSE, ReqManual := TRUE, ManualAllowed := FALSE);
ASSERT_TRUE(m.Rejected);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
END_TEST

TEST modes_fall_back_to_off
VAR m : RB_ModeManager; END_VAR
m(ReqAuto := TRUE);
ASSERT_TRUE(m.Mode = RB_MODE#Auto);
m(ReqAuto := FALSE, Fault := TRUE);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
ASSERT_TRUE(m.ModeChanged);
m(Fault := FALSE, ReqAuto := TRUE);
m(ReqAuto := FALSE, AutoAllowed := FALSE);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
m(AutoAllowed := TRUE, ReqManual := TRUE);
ASSERT_TRUE(m.Mode = RB_MODE#Manual);
(* Manual survives a machine fault, but not losing its permission *)
m(ReqManual := FALSE, Fault := TRUE);
ASSERT_TRUE(m.Mode = RB_MODE#Manual);
m(Fault := FALSE, ManualAllowed := FALSE);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
END_TEST

TEST modes_emergency_stop_forces_off
VAR m : RB_ModeManager; END_VAR
m(ReqAuto := TRUE);
m(ReqAuto := FALSE, EStopOk := FALSE);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
m(ReqManual := TRUE, EStopOk := FALSE);
ASSERT_TRUE(m.Rejected);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
m(ReqManual := FALSE, ReqAuto := TRUE, EStopOk := FALSE);
ASSERT_TRUE(m.Rejected);
(* back to normal: the mode stays Off until a new request *)
m(ReqAuto := FALSE, EStopOk := TRUE);
ASSERT_TRUE(m.Mode = RB_MODE#Off);
ASSERT_FALSE(m.Rejected);
m(EStopOk := FALSE);
ASSERT_FALSE(m.Rejected);
END_TEST

TEST machine_state_normal_cycle
VAR s : RB_MachineState; END_VAR
s();
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopped);
s(Reset := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Resetting);
s(Reset := FALSE, ResetDone := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Idle);
s(ResetDone := FALSE, Start := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Starting);
ASSERT_FALSE(s.Producing);
s(Start := FALSE, StartDone := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Execute);
ASSERT_TRUE(s.Producing);
s(StartDone := FALSE, Hold := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Held);
s(Hold := FALSE, Unhold := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Execute);
s(Unhold := FALSE, Stop := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopping);
s(Stop := FALSE, StopDone := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopped);
ASSERT_FALSE(s.Rejected);
END_TEST

TEST machine_state_done_inputs_only_in_their_state
VAR s : RB_MachineState; END_VAR
s(ResetDone := TRUE, StartDone := TRUE, StopDone := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopped);
s(ResetDone := FALSE, StartDone := FALSE, StopDone := FALSE, Reset := TRUE);
s(Reset := FALSE, StartDone := TRUE, StopDone := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Resetting);
s(StartDone := FALSE, StopDone := FALSE, ResetDone := TRUE);
s(ResetDone := FALSE, Start := TRUE);
s(Start := FALSE, ResetDone := TRUE, StopDone := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Starting);
s(ResetDone := FALSE, StopDone := FALSE, Stop := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopping);
s(Stop := FALSE, ResetDone := TRUE, StartDone := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopping);
END_TEST

TEST machine_state_abort_clear_and_rejected
VAR s : RB_MachineState; END_VAR
(* rejected in Stopped *)
s(Start := TRUE);
ASSERT_TRUE(s.Rejected);
s(Start := FALSE, Stop := TRUE);
ASSERT_TRUE(s.Rejected);
s(Stop := FALSE, Hold := TRUE);
ASSERT_TRUE(s.Rejected);
s(Hold := FALSE, Unhold := TRUE);
ASSERT_TRUE(s.Rejected);
s(Unhold := FALSE, Clear := TRUE);
ASSERT_TRUE(s.Rejected);
s(Clear := FALSE);
ASSERT_FALSE(s.Rejected);
(* abort from any state, clear back to Stopped *)
s(Abort := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Aborted);
s(Abort := FALSE);
s(Abort := TRUE);
ASSERT_TRUE(s.Rejected);
s(Abort := FALSE, Reset := TRUE);
ASSERT_TRUE(s.Rejected);
s(Reset := FALSE, Clear := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopped);
(* stop from Idle, Starting and Held *)
s(Clear := FALSE, Reset := TRUE);
s(Reset := FALSE, ResetDone := TRUE);
s(ResetDone := FALSE, Stop := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopping);
s(Stop := FALSE, StopDone := TRUE);
s(StopDone := FALSE, Reset := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Resetting);
s(Reset := FALSE);
s(Reset := TRUE);
ASSERT_TRUE(s.Rejected);
s(Reset := FALSE, ResetDone := TRUE);
s(ResetDone := FALSE, Start := TRUE);
s(Start := FALSE, Stop := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopping);
s(Stop := FALSE, StopDone := TRUE);
s(StopDone := FALSE, Reset := TRUE);
s(Reset := FALSE, ResetDone := TRUE);
s(ResetDone := FALSE, Start := TRUE);
s(Start := FALSE, StartDone := TRUE);
s(StartDone := FALSE, Hold := TRUE);
s(Hold := FALSE, Stop := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Stopping);
s(Stop := FALSE, Hold := TRUE);
ASSERT_TRUE(s.Rejected);
s(Hold := FALSE, Abort := TRUE);
ASSERT_TRUE(s.State = RB_MACHINE_STATE#Aborted);
END_TEST

TEST counter_counts_to_preset
VAR c : RB_Counter; END_VAR
c(In := FALSE, Preset := 3);
ASSERT_EQ(UDINT#3, c.Remaining);
c(In := TRUE, Preset := 3);
c(In := TRUE, Preset := 3);
ASSERT_EQ(UDINT#1, c.Count);
c(In := FALSE, Preset := 3);
c(In := TRUE, Preset := 3);
ASSERT_EQ(UDINT#2, c.Count);
ASSERT_FALSE(c.Done);
ASSERT_EQ(UDINT#1, c.Remaining);
c(In := FALSE, Preset := 3);
c(In := TRUE, Preset := 3);
ASSERT_TRUE(c.Done);
ASSERT_TRUE(c.BatchDone);
ASSERT_EQ(UDINT#1, c.Batches);
ASSERT_EQ(UDINT#0, c.Remaining);
c(In := FALSE, Preset := 3);
ASSERT_FALSE(c.BatchDone);
(* without auto restart it stays at the preset; the total goes on *)
c(In := TRUE, Preset := 3);
ASSERT_EQ(UDINT#3, c.Count);
ASSERT_EQ(UDINT#4, c.Total);
ASSERT_EQ(UDINT#1, c.Batches);
c(In := FALSE, Preset := 3, Reset := TRUE);
ASSERT_EQ(UDINT#0, c.Count);
ASSERT_FALSE(c.Done);
ASSERT_EQ(UDINT#4, c.Total);
END_TEST

TEST counter_batches_with_auto_restart
VAR c : RB_Counter; i : INT; END_VAR
FOR i := 1 TO 7 DO
    c(In := TRUE, Preset := 2, AutoRestart := TRUE);
    c(In := FALSE, Preset := 2, AutoRestart := TRUE);
END_FOR;
ASSERT_EQ(UDINT#3, c.Batches);
ASSERT_EQ(UDINT#1, c.Count);
ASSERT_EQ(UDINT#7, c.Total);
c(In := TRUE, Preset := 2, AutoRestart := TRUE);
ASSERT_TRUE(c.BatchDone);
ASSERT_TRUE(c.Done);
ASSERT_EQ(UDINT#4, c.Batches);
(* a preset lowered below the count: done at once *)
c(In := FALSE, Preset := 1, AutoRestart := FALSE, Reset := FALSE);
ASSERT_TRUE(c.Done);
ASSERT_EQ(UDINT#0, c.Remaining);
END_TEST
