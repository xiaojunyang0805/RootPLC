TEST hidden_slow_but_in_time
VAR uut : FB_ValveMonitor; i : INT; END_VAR
FOR i := 1 TO 10 DO
    uut(cmd_open := TRUE, fb_open := FALSE, fb_closed := FALSE, timeout := T#2s);
    ADVANCE(T#100ms);
END_FOR
FOR i := 1 TO 30 DO
    uut(cmd_open := TRUE, fb_open := TRUE, fb_closed := FALSE, timeout := T#2s);
    ADVANCE(T#100ms);
    ASSERT_FALSE(uut.fault);
END_FOR
END_TEST

TEST hidden_timeout_and_reset
VAR uut : FB_ValveMonitor; i : INT; END_VAR
FOR i := 1 TO 25 DO
    uut(cmd_open := TRUE, fb_open := FALSE, fb_closed := TRUE, timeout := T#2s);
    ADVANCE(T#100ms);
END_FOR
ASSERT_TRUE(uut.fault);
uut(reset := TRUE);
ASSERT_TRUE(uut.fault);
uut(reset := TRUE, fb_open := TRUE, fb_closed := FALSE);
ASSERT_FALSE(uut.fault);
END_TEST

TEST hidden_both_feedbacks_immediate
VAR uut : FB_ValveMonitor; END_VAR
uut(cmd_open := TRUE, fb_open := TRUE, fb_closed := TRUE, timeout := T#2s);
ASSERT_TRUE(uut.fault);
END_TEST
