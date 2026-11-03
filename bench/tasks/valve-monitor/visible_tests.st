TEST visible_matching_feedback_no_fault
VAR uut : FB_ValveMonitor; END_VAR
uut(cmd_open := FALSE, fb_closed := TRUE, timeout := T#2s);
ASSERT_FALSE(uut.fault);
END_TEST
