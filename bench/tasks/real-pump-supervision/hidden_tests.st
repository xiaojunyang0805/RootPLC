TEST hidden_fault_edge_latches_trip
VAR uut : FB_Pump; END_VAR
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE, xFault := TRUE);
ASSERT_TRUE(uut.xTripped);
ASSERT_FALSE(uut.xRun);
ASSERT_FALSE(uut.xHealthy);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE, xFault := FALSE);
ASSERT_TRUE(uut.xTripped);
ASSERT_FALSE(uut.xRun);
ASSERT_FALSE(uut.xHealthy);
END_TEST

TEST hidden_reset_blocked_while_fault_present
VAR uut : FB_Pump; END_VAR
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE, xFault := TRUE);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE, xFault := TRUE, xReset := TRUE);
ASSERT_TRUE(uut.xTripped);
ASSERT_FALSE(uut.xRun);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE, xFault := FALSE, xReset := TRUE);
ASSERT_FALSE(uut.xTripped);
ASSERT_TRUE(uut.xRun);
ASSERT_TRUE(uut.xHealthy);
END_TEST

TEST hidden_steady_fault_does_not_retrip_after_reset
VAR uut : FB_Pump; END_VAR
uut(xStart := FALSE, xInterlockOk := TRUE, xFault := TRUE);
ASSERT_TRUE(uut.xTripped);
uut(xStart := FALSE, xInterlockOk := TRUE, xFault := FALSE, xReset := TRUE);
ASSERT_FALSE(uut.xTripped);
uut(xStart := FALSE, xInterlockOk := TRUE, xFault := FALSE, xReset := FALSE);
ASSERT_FALSE(uut.xTripped);
ASSERT_TRUE(uut.xHealthy);
END_TEST

TEST hidden_feedback_timeout_latches
VAR uut : FB_Pump; END_VAR
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := FALSE, tFeedbackTimeout := T#2s);
ASSERT_TRUE(uut.xRun);
ADVANCE(T#1s);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := FALSE, tFeedbackTimeout := T#2s);
ASSERT_TRUE(uut.xRun);
ASSERT_FALSE(uut.xFeedbackFault);
ADVANCE(T#1s);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := FALSE, tFeedbackTimeout := T#2s);
ASSERT_TRUE(uut.xFeedbackFault);
ASSERT_FALSE(uut.xRun);
ASSERT_FALSE(uut.xHealthy);
ADVANCE(T#1s);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE, tFeedbackTimeout := T#2s);
ASSERT_TRUE(uut.xFeedbackFault);
ASSERT_FALSE(uut.xRun);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE, xReset := TRUE, tFeedbackTimeout := T#2s);
ASSERT_FALSE(uut.xFeedbackFault);
ASSERT_TRUE(uut.xRun);
END_TEST

TEST hidden_feedback_in_time_is_fine
VAR uut : FB_Pump; END_VAR
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := FALSE, tFeedbackTimeout := T#2s);
ADVANCE(T#1s);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE, tFeedbackTimeout := T#2s);
ADVANCE(T#5s);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE, tFeedbackTimeout := T#2s);
ASSERT_TRUE(uut.xRun);
ASSERT_FALSE(uut.xFeedbackFault);
END_TEST

TEST hidden_unsupervised_when_not_commanded
VAR uut : FB_Pump; END_VAR
uut(xStart := FALSE, xInterlockOk := TRUE, xRunFeedback := FALSE, tFeedbackTimeout := T#1s);
ADVANCE(T#10s);
uut(xStart := FALSE, xInterlockOk := TRUE, xRunFeedback := FALSE, tFeedbackTimeout := T#1s);
ASSERT_FALSE(uut.xFeedbackFault);
ASSERT_TRUE(uut.xHealthy);
END_TEST

TEST hidden_interlock_lost_while_running
VAR uut : FB_Pump; END_VAR
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE);
ASSERT_TRUE(uut.xRun);
uut(xStart := TRUE, xInterlockOk := FALSE, xRunFeedback := TRUE);
ASSERT_FALSE(uut.xRun);
ASSERT_TRUE(uut.xHealthy);
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE);
ASSERT_TRUE(uut.xRun);
END_TEST
