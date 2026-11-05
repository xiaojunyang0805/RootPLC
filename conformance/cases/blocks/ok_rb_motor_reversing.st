(* spec: [blocks.command] [blocks.mode] [blocks.interlock] [blocks.fault] [blocks.feedback] [blocks.status]
   expect: ok
   libraries: RootBlocks *)
(* Test suite of RB_MotorReversing (card blocks/cards/F04.MOTOR.REV.md).
   Every call passes the inputs that matter: block inputs keep their last
   value. *)
TEST reversing_forward_then_reverse_with_dead_time
VAR m : RB_MotorReversing; i : INT; both : BOOL; END_VAR
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, AutoRev := FALSE, FbFwd := FALSE, FbRev := FALSE, ReverseDelay := T#1s);
ASSERT_FALSE(m.RunFwd);
ADVANCE(T#1s);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, AutoRev := FALSE, FbFwd := FALSE, FbRev := FALSE, ReverseDelay := T#1s);
ASSERT_TRUE(m.RunFwd);
ASSERT_TRUE(m.Status.Commanded);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, AutoRev := FALSE, FbFwd := TRUE, FbRev := FALSE, ReverseDelay := T#1s);
ASSERT_TRUE(m.RunningFwd);
ASSERT_FALSE(m.RunningRev);
ASSERT_TRUE(m.Status.Active);
ASSERT_EQ(UDINT#1, m.Status.Starts);
(* reverse: forward drops at once, reverse waits for the dead time *)
m(Mode := RB_MODE#Auto, AutoFwd := FALSE, AutoRev := TRUE, FbFwd := TRUE, FbRev := FALSE, ReverseDelay := T#1s);
ASSERT_FALSE(m.RunFwd);
ASSERT_FALSE(m.RunRev);
FOR i := 1 TO 9 DO
    ADVANCE(T#100ms);
    m(Mode := RB_MODE#Auto, AutoFwd := FALSE, AutoRev := TRUE, FbFwd := FALSE, FbRev := FALSE, ReverseDelay := T#1s);
    IF m.RunRev THEN both := TRUE; END_IF;
END_FOR;
ASSERT_FALSE(both);
ADVANCE(T#200ms);
m(Mode := RB_MODE#Auto, AutoFwd := FALSE, AutoRev := TRUE, FbFwd := FALSE, FbRev := FALSE, ReverseDelay := T#1s);
ASSERT_TRUE(m.RunRev);
ASSERT_FALSE(m.RunFwd);
ASSERT_EQ(UDINT#2, m.Status.Starts);
m(Mode := RB_MODE#Auto, AutoFwd := FALSE, AutoRev := TRUE, FbFwd := FALSE, FbRev := TRUE, ReverseDelay := T#1s);
ASSERT_TRUE(m.RunningRev);
ASSERT_FALSE(m.Error);
END_TEST

TEST reversing_both_commands_stop
VAR m : RB_MotorReversing; END_VAR
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, AutoRev := FALSE, ReverseDelay := T#0s);
ASSERT_TRUE(m.RunFwd);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, AutoRev := TRUE, FbFwd := TRUE, ReverseDelay := T#0s);
ASSERT_FALSE(m.RunFwd);
ASSERT_FALSE(m.RunRev);
END_TEST

TEST reversing_modes_interlock_permissive
VAR m : RB_MotorReversing; END_VAR
m(Mode := RB_MODE#Auto, ManRev := TRUE, ReverseDelay := T#0s);
ASSERT_FALSE(m.RunRev);
m(Mode := RB_MODE#Manual, ManRev := TRUE, ManFwd := FALSE, ReverseDelay := T#0s);
ASSERT_TRUE(m.RunRev);
m(Mode := RB_MODE#Manual, ManRev := TRUE, Interlock := TRUE, FbRev := TRUE, ReverseDelay := T#0s);
ASSERT_FALSE(m.RunRev);
m(Mode := RB_MODE#Manual, ManFwd := TRUE, ManRev := FALSE, Interlock := FALSE, FbRev := FALSE, ReverseDelay := T#0s);
ASSERT_TRUE(m.RunFwd);
m(Mode := RB_MODE#Off, ManFwd := TRUE, FbFwd := TRUE, ReverseDelay := T#0s);
ASSERT_FALSE(m.RunFwd);
m(Mode := RB_MODE#Auto, AutoRev := TRUE, Permissive := FALSE, FbFwd := FALSE, ReverseDelay := T#0s);
ASSERT_FALSE(m.RunRev);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, AutoRev := FALSE, Permissive := FALSE, ReverseDelay := T#0s);
ASSERT_FALSE(m.RunFwd);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, Permissive := TRUE, ReverseDelay := T#0s);
ASSERT_TRUE(m.RunFwd);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, Permissive := FALSE, FbFwd := TRUE, ReverseDelay := T#0s);
ASSERT_TRUE(m.RunFwd);
m(Mode := RB_MODE#Auto, AutoFwd := FALSE, AutoRev := TRUE, Permissive := TRUE, FbFwd := FALSE, ReverseDelay := T#0s);
m(Mode := RB_MODE#Auto, AutoFwd := FALSE, AutoRev := TRUE, Permissive := TRUE, FbFwd := FALSE, ReverseDelay := T#0s);
ASSERT_TRUE(m.RunRev);
m(Mode := RB_MODE#Auto, AutoRev := TRUE, Permissive := FALSE, FbRev := TRUE, ReverseDelay := T#0s);
ASSERT_TRUE(m.RunRev);
END_TEST

TEST reversing_faults
VAR m : RB_MotorReversing; n : RB_MotorReversing; k : RB_MotorReversing; o : RB_MotorReversing; END_VAR
(* no feedback for the commanded direction *)
m(Mode := RB_MODE#Auto, AutoRev := TRUE, FbRev := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ADVANCE(T#1100ms);
m(Mode := RB_MODE#Auto, AutoRev := TRUE, FbRev := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_TRUE(m.Error);
ASSERT_EQ(UDINT#1, m.ErrorID);
ASSERT_FALSE(m.RunRev);
ASSERT_EQ(UDINT#1, m.Status.ErrorID);
ASSERT_TRUE(m.Status.Error);
(* forward feedback without a command *)
n(Mode := RB_MODE#Auto, FbFwd := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ADVANCE(T#1100ms);
n(Mode := RB_MODE#Auto, FbFwd := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_EQ(UDINT#2, n.ErrorID);
ASSERT_TRUE(n.Error);
(* both feedback contacts *)
k(Mode := RB_MODE#Auto, AutoFwd := TRUE, FbFwd := TRUE, FbRev := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_FALSE(k.RunningFwd);
ASSERT_FALSE(k.RunningRev);
ADVANCE(T#1100ms);
k(Mode := RB_MODE#Auto, AutoFwd := TRUE, FbFwd := TRUE, FbRev := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_EQ(UDINT#4, k.ErrorID);
ASSERT_FALSE(k.RunFwd);
(* overload, then reset *)
o(Mode := RB_MODE#Auto, AutoFwd := TRUE, Overload := TRUE, ReverseDelay := T#0s);
ASSERT_EQ(UDINT#3, o.ErrorID);
ASSERT_FALSE(o.RunFwd);
o(Mode := RB_MODE#Auto, AutoFwd := TRUE, Overload := FALSE, Reset := TRUE, ReverseDelay := T#0s);
ASSERT_FALSE(o.Error);
ASSERT_EQ(UDINT#0, o.ErrorID);
ASSERT_TRUE(o.RunFwd);
END_TEST

TEST reversing_without_feedback
VAR m : RB_MotorReversing; END_VAR
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, Feedback := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_TRUE(m.RunningFwd);
ADVANCE(T#5s);
m(Mode := RB_MODE#Auto, AutoFwd := FALSE, AutoRev := TRUE, Feedback := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
m(Mode := RB_MODE#Auto, AutoFwd := FALSE, AutoRev := TRUE, Feedback := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_TRUE(m.RunningRev);
ASSERT_FALSE(m.Error);
m(Mode := RB_MODE#Auto, AutoRev := TRUE, Feedback := TRUE, FbRev := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_FALSE(m.Error);
END_TEST

TEST reversing_details
VAR m : RB_MotorReversing; s : RB_MotorReversing; o : RB_MotorReversing; END_VAR
(* both commands from standstill: nothing runs *)
s(Mode := RB_MODE#Auto, AutoFwd := TRUE, AutoRev := TRUE, ReverseDelay := T#0s);
ASSERT_FALSE(s.RunFwd);
ASSERT_FALSE(s.RunRev);
(* Off: no direction runs *)
o(Mode := RB_MODE#Off, ManRev := TRUE, AutoRev := TRUE, ReverseDelay := T#0s);
ASSERT_FALSE(o.RunRev);
(* forward runs normally past the feedback time; starts counted once *)
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, FbFwd := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, FbFwd := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ADVANCE(T#3s);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, FbFwd := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_FALSE(m.Error);
ASSERT_EQ(UDINT#1, m.Status.Starts);
(* an interlock stops forward too *)
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, FbFwd := TRUE, Interlock := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_FALSE(m.RunFwd);
m(Mode := RB_MODE#Auto, AutoFwd := FALSE, FbFwd := FALSE, Interlock := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
(* reverse runs normally past the feedback time *)
m(Mode := RB_MODE#Auto, AutoRev := TRUE, FbRev := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ADVANCE(T#3s);
m(Mode := RB_MODE#Auto, AutoRev := TRUE, FbRev := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_FALSE(m.Error);
ASSERT_TRUE(m.RunRev);
END_TEST

TEST reversing_supervision_switched_on_starts_fresh
VAR m : RB_MotorReversing; k : RB_MotorReversing; END_VAR
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, Feedback := FALSE, FbFwd := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ADVANCE(T#5s);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, Feedback := FALSE, FbFwd := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
m(Mode := RB_MODE#Auto, AutoFwd := TRUE, Feedback := TRUE, FbFwd := FALSE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_FALSE(m.Error);
k(Mode := RB_MODE#Auto, AutoFwd := TRUE, Feedback := FALSE, FbFwd := TRUE, FbRev := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ADVANCE(T#5s);
k(Mode := RB_MODE#Auto, AutoFwd := TRUE, Feedback := FALSE, FbFwd := TRUE, FbRev := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
k(Mode := RB_MODE#Auto, AutoFwd := TRUE, Feedback := TRUE, FbFwd := TRUE, FbRev := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_FALSE(k.Error);
ADVANCE(T#1100ms);
k(Mode := RB_MODE#Auto, AutoFwd := TRUE, Feedback := TRUE, FbFwd := TRUE, FbRev := TRUE, ReverseDelay := T#0s, FeedbackTime := T#1s);
ASSERT_TRUE(k.Error);
ASSERT_EQ(UDINT#4, k.ErrorID);
END_TEST
