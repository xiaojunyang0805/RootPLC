TEST visible_runs_when_started_and_safe
VAR uut : FB_Pump; END_VAR
uut(xStart := TRUE, xInterlockOk := TRUE, xRunFeedback := TRUE);
ASSERT_TRUE(uut.xRun);
ASSERT_TRUE(uut.xHealthy);
END_TEST

TEST visible_interlock_stops
VAR uut : FB_Pump; END_VAR
uut(xStart := TRUE, xInterlockOk := FALSE, xRunFeedback := FALSE);
ASSERT_FALSE(uut.xRun);
END_TEST
